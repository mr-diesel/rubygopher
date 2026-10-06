import { request } from "./client";

const query = (params) => {
  const qs = new URLSearchParams(Object.entries(params).filter(([, v]) => v != null && v !== "")).toString();
  return qs ? `?${qs}` : "";
};

export const listApplications = (params = {}) => request(`/applications${query(params)}`);
export const getApplication = (id) => request(`/applications/${id}`);
export const createApplication = (data) => request("/applications", { method: "POST", body: data });
export const addApplicationEvent = (id, data) => request(`/applications/${id}/events`, { method: "POST", body: data });

export const listOutreaches = (params = {}) => request(`/outreaches${query(params)}`);
export const getOutreach = (id) => request(`/outreaches/${id}`);
export const createOutreach = (data) => request("/outreaches", { method: "POST", body: data });
export const changeOutreachStatus = (id, data) => request(`/outreaches/${id}/status`, { method: "POST", body: data });
