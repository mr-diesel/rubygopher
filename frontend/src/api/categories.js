import { request } from "./client";

export const listCategories = () => request("/interview_categories");
export const reorderCategories = (ordered) =>
  request("/interview_categories/reorder", { method: "PATCH", body: { ordered } });
