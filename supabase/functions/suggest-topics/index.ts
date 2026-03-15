import { assertPost, getRequiredJsonParameters, serve } from "../_shared/http.ts";
import { getServiceRoleSupabaseClient } from "../_shared/supabase.ts";

// deno-lint-ignore no-explicit-any
let pipeline: any = null;

async function getEmbeddingPipeline() {
  if (pipeline) return pipeline;

  const { pipeline: createPipeline } = await import(
    "https://esm.sh/@xenova/transformers@2.17.2"
  );

  pipeline = await createPipeline(
    "feature-extraction",
    "Xenova/all-MiniLM-L6-v2",
    { quantized: true },
  );

  return pipeline;
}

serve(async (request) => {
  assertPost(request);

  const { query } = await getRequiredJsonParameters(request, ["query"]);

  // Compute embedding for the query
  const extractor = await getEmbeddingPipeline();
  const output = await extractor(query, {
    pooling: "mean",
    normalize: true,
  });

  const embedding = Array.from(output.data) as number[];

  // Search for similar topics using the embedding
  const supabase = getServiceRoleSupabaseClient();

  const { data: suggestions, error } = await supabase.rpc(
    "search_similar_topics",
    {
      query_embedding: JSON.stringify(embedding),
      similarity_threshold: 0.4,
      max_results: 10,
    },
  );

  if (error) {
    throw new Error(`Failed to search similar topics: ${error.message}`);
  }

  return new Response(
    JSON.stringify({
      suggestions: suggestions ?? [],
      embedding,
    }),
    {
      headers: { "Content-Type": "application/json" },
      status: 200,
    },
  );
});
