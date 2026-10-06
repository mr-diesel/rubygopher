import { request } from "./client";

export const fetchDigest = () => request("/digest");
export const markVacanciesSeen = () => request("/digest/vacancies_seen", { method: "POST" });
export const markFollowUpSent = (applicationId, nextFollowUpAt) =>
  request(`/applications/${applicationId}/events`, {
    method: "POST",
    body: { event_type: "follow_up_sent", next_follow_up_at: nextFollowUpAt }
  });
