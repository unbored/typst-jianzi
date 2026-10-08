import { readFileSync } from 'node:fs';

const file = process.argv[2];
const binary = readFileSync(file);
const module = new WebAssembly.Module(binary);
const allowed = new Set([
  'wasm_minimal_protocol_write_args_to_buffer',
  'wasm_minimal_protocol_send_result_to_host',
]);
const imports = WebAssembly.Module.imports(module);
for (const item of imports) {
  if (item.module !== 'typst_env' || item.kind !== 'function' || !allowed.has(item.name)) {
    throw new Error(`Unsupported import: ${item.module}.${item.name} (${item.kind})`);
  }
}
for (const name of allowed) {
  if (!imports.some(item => item.name === name)) throw new Error(`Missing protocol import: ${name}`);
}
const exports = WebAssembly.Module.exports(module);
for (const name of ['memory', 'init', 'metrics', 'render_natural']) {
  const kind = name === 'memory' ? 'memory' : 'function';
  if (!exports.some(item => item.name === name && item.kind === kind)) {
    throw new Error(`Missing ${kind} export: ${name}`);
  }
}
if (exports.some(item => item.kind === 'tag')) throw new Error('Exception handling export detected');
// Tags need not be exported. Also reject a local tag section and an explicit
// exception-handling feature, rather than just inspecting exported names.
let offset = 8;
const uleb = () => {
  let value = 0, shift = 0, byte;
  do {
    byte = binary[offset++];
    value += (byte & 127) * 2 ** shift;
    shift += 7;
  } while (byte & 128);
  return value;
};
while (offset < binary.length) {
  const id = binary[offset++];
  const length = uleb();
  if (id === 13) throw new Error('Exception handling tag section detected');
  offset += length;
}
for (const section of WebAssembly.Module.customSections(module, 'target_features')) {
  if (Buffer.from(section).includes(Buffer.from('exception-handling'))) {
    throw new Error('Exception handling target feature detected');
  }
}
console.log(`Validated ${file}: only minimal-protocol imports; memory/init/metrics/render_natural exported.`);
