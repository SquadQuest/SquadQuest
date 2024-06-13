function assert(shouldBeTrue: boolean, message: string, status: number = 400, errorId?: string) {
  if (!shouldBeTrue) {
    throw new HttpError(message, status, errorId);
  }
}

function assertMethod(request: Request, method: string) {
  if (request.method != method) {
    throw new HttpError(`Only ${method} supported`, 405);
  }
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
  assertJson,
  assertMethod,
  assertPost,
  getRequiredJsonParameters,
  HttpError,
  debugResponse,
};
