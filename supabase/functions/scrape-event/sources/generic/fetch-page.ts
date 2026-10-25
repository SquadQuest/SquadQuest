import { assert } from "../../../_shared/http.ts";

const BROWSER_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
  "Accept-Language": "en-US,en;q=0.9",
};

const BLOCKED_MESSAGE =
  "This site blocks automated access, try entering the event manually";

const PAGE_TIMEOUT_MS = 10_000;
const PAGE_MAX_BYTES = 3 * 1024 * 1024;

export interface FetchedText {
  text: string;
  /** Final URL after redirects */
  url: URL;
  contentType: string;
}

/** Read a response body as text, stopping once `maxBytes` have arrived */
async function readLimited(response: Response, maxBytes: number) {
  if (!response.body) return "";

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;

  while (total < maxBytes) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    total += value.length;
  }
  await reader.cancel().catch(() => {});

  const bytes = new Uint8Array(Math.min(total, maxBytes));
  let offset = 0;
  for (const chunk of chunks) {
    const slice = chunk.subarray(0, bytes.length - offset);
    bytes.set(slice, offset);
    offset += slice.length;
    if (offset >= bytes.length) break;
  }

  return new TextDecoder().decode(bytes);
}

/** Fetch a URL with browser-like headers, a timeout, and a size cap */
export async function fetchText(
  url: URL | string,
  accept = "*/*",
  timeoutMs = 5_000,
  maxBytes = 1024 * 1024,
): Promise<FetchedText> {
  const response = await fetch(url, {
    headers: { ...BROWSER_HEADERS, Accept: accept },
    redirect: "follow",
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!response.ok) {
    await response.body?.cancel();
    throw new FetchError(response.status);
  }

  return {
    text: await readLimited(response, maxBytes),
    url: new URL(response.url || url),
    contentType: response.headers.get("content-type") ?? "",
  };
}

export class FetchError extends Error {
  constructor(public status: number) {
    super(`Request failed with status ${status}`);
  }
}

const BLOCKED_PAGE_TITLES =
  /^\s*(just a moment|attention required|client challenge|vercel security checkpoint|access denied|security check)/i;

/** Whether HTML is a bot-protection challenge rather than the real page.
 * Challenges come back with 200, 202, and 429 statuses alike, so this looks
 * at the content. Normal pages often embed the same challenge scripts, so
 * script markers only count on tiny pages. */
export function isBlockedPage(html: string): boolean {
  const title = html.match(/<title[^>]*>([^<]*)/i)?.[1] ?? "";
  if (BLOCKED_PAGE_TITLES.test(title)) return true;
  return html.length < 20_000 &&
    /awsWafCookieDomainList|cf_chl_opt|_cf_chl|captcha-delivery\.com/.test(
      html,
    );
}

/** Fetch an event page's HTML, with errors worded for the person importing it */
export async function fetchPage(url: URL): Promise<FetchedText> {
  let page: FetchedText;

  try {
    page = await fetchText(
      url,
      "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
      PAGE_TIMEOUT_MS,
      PAGE_MAX_BYTES,
    );
  } catch (error) {
    if (error instanceof FetchError) {
      assert(error.status != 404 && error.status != 410, "Page not found");
      assert(
        ![401, 403, 429, 503].includes(error.status),
        BLOCKED_MESSAGE,
      );
      assert(false, `Failed to load page (status ${error.status})`);
    }
    if (error instanceof DOMException && error.name == "TimeoutError") {
      assert(false, "Timed out loading page");
    }
    assert(false, "Failed to load page");
    throw error;
  }

  assert(
    !page.contentType || /html|xml|text\/plain/i.test(page.contentType),
    "This link doesn't point to a web page",
  );
  assert(!isBlockedPage(page.text), BLOCKED_MESSAGE);

  return page;
}
