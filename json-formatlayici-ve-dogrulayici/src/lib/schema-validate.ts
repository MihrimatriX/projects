import Ajv, { type ErrorObject } from "ajv";

const ajv = new Ajv({ allErrors: true, strict: false });

export interface SchemaValidationResult {
  valid: boolean;
  errors: string[];
}

export function validateAgainstSchema(
  data: unknown,
  schemaText: string
): SchemaValidationResult {
  if (!schemaText.trim()) {
    return { valid: true, errors: [] };
  }

  try {
    const schema = JSON.parse(schemaText) as object;
    const validate = ajv.compile(schema);
    const valid = validate(data);

    if (valid) {
      return { valid: true, errors: [] };
    }

    const errors = (validate.errors ?? []).map(formatAjvError);
    return { valid: false, errors };
  } catch (err) {
    return {
      valid: false,
      errors: [err instanceof Error ? err.message : String(err)],
    };
  }
}

function formatAjvError(err: ErrorObject): string {
  const path = err.instancePath || "/";
  const msg = err.message ?? "doğrulama hatası";
  return `${path}: ${msg}`;
}
