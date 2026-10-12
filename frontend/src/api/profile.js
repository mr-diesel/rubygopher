import { request } from "./client";

export const getProfile = () => request("/me");
export const updateProfile = (data) => request("/me", { method: "PATCH", body: data });
