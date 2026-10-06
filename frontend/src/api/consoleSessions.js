import { request } from "./client";

export const createSession = (code, context) =>
  request("/console/sessions", { method: "POST", body: { code, context } });

export const fetchSession = (token) => request(`/console/sessions/${token}`);
