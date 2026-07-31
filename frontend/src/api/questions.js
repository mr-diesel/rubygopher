import { request } from "./client";

export const listQuestions = () => request("/interview_questions");
export const createQuestion = (data) => request("/interview_questions", { method: "POST", body: data });
export const updateQuestion = (id, data) => request(`/interview_questions/${id}`, { method: "PATCH", body: data });
export const deleteQuestion = (id) => request(`/interview_questions/${id}`, { method: "DELETE" });
export const hideQuestion = (id) => request(`/interview_questions/${id}/hide`, { method: "POST" });
export const reorderQuestions = (orderedIds) =>
  request("/interview_questions/reorder", { method: "PATCH", body: { ordered_ids: orderedIds } });
