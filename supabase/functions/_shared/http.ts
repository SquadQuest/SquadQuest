const port = (Deno.env.get("PORT") ?? 8000) as number;

function serve(handler: Deno.ServeHandler) {
  Deno.serve({ port }, async (request, info) => {
    try {
      return await handler(request, info);
    } catch (error) {
      if (error instanceof HttpError) {
        let message = error.message;

        if (error.errorId) {
          message = `${error.errorId}: ${message}`;
        }

        return new Response(
          message,
          {
            status: error.code,
          },
        );
      }

      return new Response(
        JSON.stringify({
          message: String(error?.message ?? error),
          error_id: error.errorId,
        }),
        {
          headers: { "Content-Type": "application/json" },
          status: 500,
        },
      );
    }
  });
}

function assert(
  shouldBeTrue: boolean,
  message: string,
  status: number = 400,
  errorId?: string,
) {
  if (!shouldBeTrue) {
    throw new HttpError(message, status, errorId);
  }
}

function assertMethod(request: Request, method: string) {
  if (request.method != method) {
    throw new HttpError(`Only ${method} supported`, 405);
  }
}

function assertGet(request: Request) {
  assertMethod(request, "GET");
}

function assertPost(request: Request) {
  assertMethod(request, "POST");
}

const jsonHeaderRegexp = /^application\/json(;.*)?/;
function assertJson(request: Request) {
  if (!jsonHeaderRegexp.test(request.headers.get("content-type")!)) {
    throw new HttpError(
      "Request body must be JSON. Check Content-Type header.",
      415,
    );
  }
}

function getRequiredQueryParameters(
  request: Request,
  parameters: Array<string>,
) {
  let queryParams;

  try {
    queryParams = new URL(request.url).searchParams;
  } catch (error) {
    throw new HttpError(
      `Failed to parse query parameters: ${error?.message ?? error}`,
      400,
    );
  }

  for (const parameter of parameters) {
    if (!queryParams.has(parameter)) {
      throw new HttpError(
        `Required parameter missing from query: ${parameter}`,
        400,
      );
    }
  }

  return Object.fromEntries(queryParams);
}

async function getRequiredJsonParameters(
  request: Request,
  parameters: Array<string>,
) {
  assertJson(request);

  let body;

  try {
    body = await request.json();
  } catch (error) {
    throw new HttpError(
      `Failed to parse JSON request body: ${error?.message ?? error}`,
      400,
    );
  }

  for (const parameter of parameters) {
    if (!(parameter in body)) {
      throw new HttpError(
        `Required parameter missing from JSON request body: ${parameter}`,
        400,
      );
    }
  }

  return body;
}

class HttpError extends Error {
  code: number;
  errorId?: string;

  constructor(message: string, code: number, errorId?: string) {
    super(message);

    this.code = code;
    this.errorId = errorId;

    // Set the prototype explicitly.
    Object.setPrototypeOf(this, HttpError.prototype);
  }

  sayHello() {
    return "hello " + this.message;
  }
}

function debugResponse(message: string, data?: object) {
  return new Response(
    JSON.stringify({ message, data }),
    {
      headers: { "Content-Type": "application/json" },
      status: 501,
    },
  );
}

export {
  assert,
  assertGet,
  assertJson,
  assertMethod,
  assertPost,
  debugResponse,
  getRequiredJsonParameters,
  getRequiredQueryParameters,
  HttpError,
  serve,
};
