import { request } from "./client";

// context: "rails" | "ruby" | "go", all executed in the sandbox service
export const runCode = (code, context, session) =>
  request("/console/eval", { method: "POST", body: { code, context, session: session || undefined } });
