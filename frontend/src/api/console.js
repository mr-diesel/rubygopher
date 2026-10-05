import { request } from "./client";

// context: "rails" (models + DB, fork of the Rails process) | "ruby" (bare subprocess)
export const runCode = (code, context) =>
  request("/console/eval", { method: "POST", body: { code, context } });
