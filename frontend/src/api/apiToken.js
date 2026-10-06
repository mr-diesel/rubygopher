import { request } from "./client";

export const apiTokenStatus = () => request("/me/api_token");
export const regenerateApiToken = () => request("/me/api_token", { method: "POST" });
export const revokeApiToken = () => request("/me/api_token", { method: "DELETE" });
