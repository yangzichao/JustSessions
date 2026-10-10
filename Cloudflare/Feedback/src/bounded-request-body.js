/**
 * The request body as text, or null once it passes `maximumBytes`, read only that far whether or not the client
 * declared its length.
 */
export async function readBoundedRequestText(request, maximumBytes) {
  if (Number(request.headers.get("Content-Length")) > maximumBytes) return null;
  if (!request.body) return "";
  const reader = request.body.getReader();
  const chunks = [];
  let byteCount = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    byteCount += value.byteLength;
    if (byteCount > maximumBytes) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(byteCount);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}
