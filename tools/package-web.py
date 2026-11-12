#!/usr/bin/env python3
"""Split the engine's WASM below hosting object limits; stream the pieces as one response."""
from pathlib import Path
import sys
root = Path(sys.argv[1] if len(sys.argv) > 1 else 'build/web')
wasm = root / 'index.wasm'
if not wasm.exists():
    raise SystemExit('Expected a fresh Godot export with index.wasm')
blob = wasm.read_bytes()
chunk_size = 20 * 1024 * 1024
parts = [blob[i:i + chunk_size] for i in range(0, len(blob), chunk_size)]
for i, chunk in enumerate(parts):
    (root / f'index.wasm.part{i}').write_bytes(chunk)
html = root / 'index.html'
marker = '<script src="index.js"></script>'
loader = '''<script>
// Only the engine WASM is split. Other requests retain ordinary fetch behavior.
const originalFetch = window.fetch.bind(window);
const wasmURL = new URL('index.wasm', location.href).href;
window.fetch = (resource, options) => {
  const url = new URL(resource instanceof Request ? resource.url : resource, location.href).href;
  if (url !== wasmURL) return originalFetch(resource, options);
  let reader;
  const body = new ReadableStream({
    async start(controller) {
      try {
        for (let i = 0; i < PART_COUNT; i++) {
          const response = await originalFetch(wasmURL + '.part' + i, options);
          if (!response.ok) throw new Error('Engine download failed: ' + response.status);
          reader = response.body.getReader();
          while (true) {
            const {done, value} = await reader.read();
            if (done) break;
            controller.enqueue(value);
          }
        }
        controller.close();
      } catch (error) { controller.error(error); }
    },
    cancel(reason) { return reader?.cancel(reason); }
  });
  return Promise.resolve(new Response(body, {headers: {'Content-Type': 'application/wasm', 'Content-Length': 'TOTAL_SIZE'}}));
};
</script>
'''.replace('PART_COUNT', str(len(parts))).replace('TOTAL_SIZE', str(len(blob)))
text = html.read_text()
if marker not in text:
    raise SystemExit('Expected Godot engine script tag missing')
html.write_text(text.replace(marker, loader + marker))
wasm.unlink()
for imported in root.glob('*.import'):
    imported.unlink()
assert b''.join((root / f'index.wasm.part{i}').read_bytes() for i in range(len(parts))) == blob
print(f'Packaged {len(parts)} WASM parts; verified byte-for-byte reconstruction')
