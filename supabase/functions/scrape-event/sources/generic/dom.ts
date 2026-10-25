import type {
  Document,
  Element,
} from "https://deno.land/x/deno_dom@v0.1.45/deno-dom-wasm.ts";

export {
  type Document,
  DOMParser,
  type Element,
} from "https://deno.land/x/deno_dom@v0.1.45/deno-dom-wasm.ts";

/** querySelectorAll, typed as the Elements it always returns */
export function elements(
  root: Document | Element,
  selector: string,
): Element[] {
  return [...root.querySelectorAll(selector)] as Element[];
}
