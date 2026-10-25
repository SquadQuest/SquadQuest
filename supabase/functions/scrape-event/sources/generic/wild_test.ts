import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { replay, WILD_DIR, WildCase } from "./fixtures/capture.ts";

// Regression cases captured from real event pages; add more with
// fixtures/capture.ts. Each replays its recorded calendar files, timezone
// lookups, and LLM answer, so these run offline.
for await (const entry of Deno.readDir(WILD_DIR)) {
  if (!entry.name.endsWith(".json")) continue;
  const slug = entry.name.replace(/\.json$/, "");

  Deno.test(`wild: ${slug}`, async () => {
    const wild: WildCase = JSON.parse(
      await Deno.readTextFile(new URL(entry.name, WILD_DIR)),
    );
    const html = await Deno.readTextFile(new URL(`${slug}.html`, WILD_DIR));
    assertEquals(await replay(html, wild), wild.expected);
  });
}
