import { request } from "./client";

export const listVacancies = (params = {}) => {
  const qs = new URLSearchParams(Object.entries(params).filter(([, v]) => v != null && v !== "" && v !== false)).toString();
  return request(`/vacancies${qs ? `?${qs}` : ""}`);
};
