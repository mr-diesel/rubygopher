SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admins (
    id bigint NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp(6) without time zone,
    last_sign_in_at timestamp(6) without time zone,
    current_sign_in_ip character varying,
    last_sign_in_ip character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: admins_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admins_id_seq OWNED BY public.admins.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id bigint NOT NULL,
    name character varying NOT NULL,
    website character varying,
    description text,
    source integer DEFAULT 0 NOT NULL,
    external_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: companies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: companies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.companies_id_seq OWNED BY public.companies.id;


--
-- Name: company_outreach_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_outreach_events (
    id bigint NOT NULL,
    company_outreach_id bigint NOT NULL,
    status integer NOT NULL,
    comment text,
    changed_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: company_outreach_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.company_outreach_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_outreach_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.company_outreach_events_id_seq OWNED BY public.company_outreach_events.id;


--
-- Name: company_outreaches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_outreaches (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    company_id bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    sent_at timestamp(6) without time zone NOT NULL,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: company_outreaches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.company_outreaches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: company_outreaches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.company_outreaches_id_seq OWNED BY public.company_outreaches.id;


--
-- Name: hidden_interview_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hidden_interview_questions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    interview_question_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: hidden_interview_questions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.hidden_interview_questions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: hidden_interview_questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.hidden_interview_questions_id_seq OWNED BY public.hidden_interview_questions.id;


--
-- Name: interview_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interview_questions (
    id bigint NOT NULL,
    user_id bigint,
    label character varying NOT NULL,
    question text NOT NULL,
    answer text,
    code text,
    language character varying,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    category character varying DEFAULT 'General'::character varying NOT NULL
);


--
-- Name: interview_questions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.interview_questions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: interview_questions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.interview_questions_id_seq OWNED BY public.interview_questions.id;


--
-- Name: job_application_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_application_events (
    id bigint NOT NULL,
    job_application_id bigint NOT NULL,
    event_type integer NOT NULL,
    status integer,
    comment text,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: job_application_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.job_application_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: job_application_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.job_application_events_id_seq OWNED BY public.job_application_events.id;


--
-- Name: job_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_applications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    company_id bigint NOT NULL,
    vacancy_id bigint NOT NULL,
    via_posting_id bigint,
    apply_url character varying,
    status integer DEFAULT 0 NOT NULL,
    applied_at timestamp(6) without time zone NOT NULL,
    last_activity_at timestamp(6) without time zone,
    next_follow_up_at timestamp(6) without time zone,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: job_applications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.job_applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: job_applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.job_applications_id_seq OWNED BY public.job_applications.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: skills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.skills (
    id bigint NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    aliases jsonb DEFAULT '[]'::jsonb NOT NULL,
    category integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: skills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.skills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: skills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.skills_id_seq OWNED BY public.skills.id;


--
-- Name: user_category_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_category_orders (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    category character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_category_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_category_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_category_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_category_orders_id_seq OWNED BY public.user_category_orders.id;


--
-- Name: user_question_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_question_orders (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    interview_question_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_question_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_question_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_question_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_question_orders_id_seq OWNED BY public.user_question_orders.id;


--
-- Name: user_skills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_skills (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    skill_id bigint NOT NULL,
    level integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: user_skills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_skills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_skills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_skills_id_seq OWNED BY public.user_skills.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp(6) without time zone,
    last_sign_in_at timestamp(6) without time zone,
    current_sign_in_ip character varying,
    last_sign_in_ip character varying,
    jti character varying NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: vacancies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vacancies (
    id bigint NOT NULL,
    company_id bigint NOT NULL,
    title character varying NOT NULL,
    language integer DEFAULT 0 NOT NULL,
    location character varying,
    work_mode integer,
    salary_min integer,
    salary_max integer,
    currency character varying,
    description text,
    published_at timestamp(6) without time zone,
    skills_extracted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: vacancies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vacancies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vacancies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vacancies_id_seq OWNED BY public.vacancies.id;


--
-- Name: vacancy_postings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vacancy_postings (
    id bigint NOT NULL,
    vacancy_id bigint NOT NULL,
    source integer NOT NULL,
    external_id character varying NOT NULL,
    url character varying NOT NULL,
    raw jsonb DEFAULT '{}'::jsonb NOT NULL,
    first_seen_at timestamp(6) without time zone NOT NULL,
    last_seen_at timestamp(6) without time zone NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: vacancy_postings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vacancy_postings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vacancy_postings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vacancy_postings_id_seq OWNED BY public.vacancy_postings.id;


--
-- Name: vacancy_skills; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vacancy_skills (
    id bigint NOT NULL,
    vacancy_id bigint NOT NULL,
    skill_id bigint NOT NULL,
    source integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: vacancy_skills_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vacancy_skills_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vacancy_skills_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vacancy_skills_id_seq OWNED BY public.vacancy_skills.id;


--
-- Name: admins id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins ALTER COLUMN id SET DEFAULT nextval('public.admins_id_seq'::regclass);


--
-- Name: companies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies ALTER COLUMN id SET DEFAULT nextval('public.companies_id_seq'::regclass);


--
-- Name: company_outreach_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_outreach_events ALTER COLUMN id SET DEFAULT nextval('public.company_outreach_events_id_seq'::regclass);


--
-- Name: company_outreaches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_outreaches ALTER COLUMN id SET DEFAULT nextval('public.company_outreaches_id_seq'::regclass);


--
-- Name: hidden_interview_questions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_interview_questions ALTER COLUMN id SET DEFAULT nextval('public.hidden_interview_questions_id_seq'::regclass);


--
-- Name: interview_questions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_questions ALTER COLUMN id SET DEFAULT nextval('public.interview_questions_id_seq'::regclass);


--
-- Name: job_application_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_application_events ALTER COLUMN id SET DEFAULT nextval('public.job_application_events_id_seq'::regclass);


--
-- Name: job_applications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_applications ALTER COLUMN id SET DEFAULT nextval('public.job_applications_id_seq'::regclass);


--
-- Name: skills id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.skills ALTER COLUMN id SET DEFAULT nextval('public.skills_id_seq'::regclass);


--
-- Name: user_category_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_category_orders ALTER COLUMN id SET DEFAULT nextval('public.user_category_orders_id_seq'::regclass);


--
-- Name: user_question_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_question_orders ALTER COLUMN id SET DEFAULT nextval('public.user_question_orders_id_seq'::regclass);


--
-- Name: user_skills id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_skills ALTER COLUMN id SET DEFAULT nextval('public.user_skills_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: vacancies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacancies ALTER COLUMN id SET DEFAULT nextval('public.vacancies_id_seq'::regclass);


--
-- Name: vacancy_postings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacancy_postings ALTER COLUMN id SET DEFAULT nextval('public.vacancy_postings_id_seq'::regclass);


--
-- Name: vacancy_skills id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacancy_skills ALTER COLUMN id SET DEFAULT nextval('public.vacancy_skills_id_seq'::regclass);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: company_outreach_events company_outreach_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_outreach_events
    ADD CONSTRAINT company_outreach_events_pkey PRIMARY KEY (id);


--
-- Name: company_outreaches company_outreaches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_outreaches
    ADD CONSTRAINT company_outreaches_pkey PRIMARY KEY (id);


--
-- Name: hidden_interview_questions hidden_interview_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_interview_questions
    ADD CONSTRAINT hidden_interview_questions_pkey PRIMARY KEY (id);


--
-- Name: interview_questions interview_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_questions
    ADD CONSTRAINT interview_questions_pkey PRIMARY KEY (id);


--
-- Name: job_application_events job_application_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_application_events
    ADD CONSTRAINT job_application_events_pkey PRIMARY KEY (id);


--
-- Name: job_applications job_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT job_applications_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: skills skills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.skills
    ADD CONSTRAINT skills_pkey PRIMARY KEY (id);


--
-- Name: user_category_orders user_category_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_category_orders
    ADD CONSTRAINT user_category_orders_pkey PRIMARY KEY (id);


--
-- Name: user_question_orders user_question_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_question_orders
    ADD CONSTRAINT user_question_orders_pkey PRIMARY KEY (id);


--
-- Name: user_skills user_skills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_skills
    ADD CONSTRAINT user_skills_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: vacancies vacancies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacancies
    ADD CONSTRAINT vacancies_pkey PRIMARY KEY (id);


--
-- Name: vacancy_postings vacancy_postings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacancy_postings
    ADD CONSTRAINT vacancy_postings_pkey PRIMARY KEY (id);


--
-- Name: vacancy_skills vacancy_skills_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacancy_skills
    ADD CONSTRAINT vacancy_skills_pkey PRIMARY KEY (id);


--
-- Name: idx_on_company_outreach_id_changed_at_43bc0f2264; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_company_outreach_id_changed_at_43bc0f2264 ON public.company_outreach_events USING btree (company_outreach_id, changed_at);


--
-- Name: idx_on_job_application_id_occurred_at_1adce1b496; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_job_application_id_occurred_at_1adce1b496 ON public.job_application_events USING btree (job_application_id, occurred_at);


--
-- Name: idx_on_user_id_interview_question_id_68cd079f8b; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_user_id_interview_question_id_68cd079f8b ON public.hidden_interview_questions USING btree (user_id, interview_question_id);


--
-- Name: idx_on_user_id_interview_question_id_a3c538bc08; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_user_id_interview_question_id_a3c538bc08 ON public.user_question_orders USING btree (user_id, interview_question_id);


--
-- Name: index_admins_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_admins_on_email ON public.admins USING btree (email);


--
-- Name: index_admins_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_admins_on_reset_password_token ON public.admins USING btree (reset_password_token);


--
-- Name: index_companies_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_companies_on_name ON public.companies USING btree (name);


--
-- Name: index_companies_on_source_and_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_companies_on_source_and_external_id ON public.companies USING btree (source, external_id) WHERE (external_id IS NOT NULL);


--
-- Name: index_company_outreaches_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_company_outreaches_on_company_id ON public.company_outreaches USING btree (company_id);


--
-- Name: index_company_outreaches_on_user_id_and_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_company_outreaches_on_user_id_and_company_id ON public.company_outreaches USING btree (user_id, company_id);


--
-- Name: index_hidden_interview_questions_on_interview_question_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_hidden_interview_questions_on_interview_question_id ON public.hidden_interview_questions USING btree (interview_question_id);


--
-- Name: index_interview_questions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interview_questions_on_user_id ON public.interview_questions USING btree (user_id);


--
-- Name: index_interview_questions_on_user_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interview_questions_on_user_id_and_position ON public.interview_questions USING btree (user_id, "position");


--
-- Name: index_job_applications_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_job_applications_on_company_id ON public.job_applications USING btree (company_id);


--
-- Name: index_job_applications_on_user_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_job_applications_on_user_id_and_status ON public.job_applications USING btree (user_id, status);


--
-- Name: index_job_applications_on_user_id_and_vacancy_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_job_applications_on_user_id_and_vacancy_id ON public.job_applications USING btree (user_id, vacancy_id);


--
-- Name: index_job_applications_on_vacancy_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_job_applications_on_vacancy_id ON public.job_applications USING btree (vacancy_id);


--
-- Name: index_job_applications_on_via_posting_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_job_applications_on_via_posting_id ON public.job_applications USING btree (via_posting_id);


--
-- Name: index_job_applications_pending_follow_up; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_job_applications_pending_follow_up ON public.job_applications USING btree (next_follow_up_at) WHERE ((archived_at IS NULL) AND (next_follow_up_at IS NOT NULL));


--
-- Name: index_skills_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_skills_on_slug ON public.skills USING btree (slug);


--
-- Name: index_user_category_orders_on_user_id_and_category; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_category_orders_on_user_id_and_category ON public.user_category_orders USING btree (user_id, category);


--
-- Name: index_user_question_orders_on_interview_question_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_question_orders_on_interview_question_id ON public.user_question_orders USING btree (interview_question_id);


--
-- Name: index_user_skills_on_skill_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_skills_on_skill_id ON public.user_skills USING btree (skill_id);


--
-- Name: index_user_skills_on_user_id_and_skill_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_skills_on_user_id_and_skill_id ON public.user_skills USING btree (user_id, skill_id);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_jti; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_jti ON public.users USING btree (jti);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_vacancies_on_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vacancies_on_company_id ON public.vacancies USING btree (company_id);


--
-- Name: index_vacancies_on_language_and_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vacancies_on_language_and_published_at ON public.vacancies USING btree (language, published_at);


--
-- Name: index_vacancies_pending_skill_extraction; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vacancies_pending_skill_extraction ON public.vacancies USING btree (skills_extracted_at) WHERE (skills_extracted_at IS NULL);


--
-- Name: index_vacancy_postings_on_source_and_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_vacancy_postings_on_source_and_external_id ON public.vacancy_postings USING btree (source, external_id);


--
-- Name: index_vacancy_postings_on_vacancy_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vacancy_postings_on_vacancy_id ON public.vacancy_postings USING btree (vacancy_id);


--
-- Name: index_vacancy_skills_on_skill_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_vacancy_skills_on_skill_id ON public.vacancy_skills USING btree (skill_id);


--
-- Name: index_vacancy_skills_on_vacancy_id_and_skill_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_vacancy_skills_on_vacancy_id_and_skill_id ON public.vacancy_skills USING btree (vacancy_id, skill_id);


--
-- Name: company_outreaches fk_rails_0d78db2b23; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_outreaches
    ADD CONSTRAINT fk_rails_0d78db2b23 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: job_applications fk_rails_0e9ee51b69; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT fk_rails_0e9ee51b69 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: job_applications fk_rails_1ccefdd180; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT fk_rails_1ccefdd180 FOREIGN KEY (vacancy_id) REFERENCES public.vacancies(id) ON DELETE RESTRICT;


--
-- Name: vacancy_skills fk_rails_276aa5f19e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacancy_skills
    ADD CONSTRAINT fk_rails_276aa5f19e FOREIGN KEY (skill_id) REFERENCES public.skills(id) ON DELETE CASCADE;


--
-- Name: user_question_orders fk_rails_3cd041c1ae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_question_orders
    ADD CONSTRAINT fk_rails_3cd041c1ae FOREIGN KEY (interview_question_id) REFERENCES public.interview_questions(id) ON DELETE CASCADE;


--
-- Name: hidden_interview_questions fk_rails_445f4cb9de; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_interview_questions
    ADD CONSTRAINT fk_rails_445f4cb9de FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_question_orders fk_rails_524dd5a445; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_question_orders
    ADD CONSTRAINT fk_rails_524dd5a445 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_skills fk_rails_59acb6e327; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_skills
    ADD CONSTRAINT fk_rails_59acb6e327 FOREIGN KEY (skill_id) REFERENCES public.skills(id) ON DELETE CASCADE;


--
-- Name: company_outreach_events fk_rails_60286be210; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_outreach_events
    ADD CONSTRAINT fk_rails_60286be210 FOREIGN KEY (company_outreach_id) REFERENCES public.company_outreaches(id) ON DELETE CASCADE;


--
-- Name: job_applications fk_rails_61abb2956c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT fk_rails_61abb2956c FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE RESTRICT;


--
-- Name: user_category_orders fk_rails_621935216d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_category_orders
    ADD CONSTRAINT fk_rails_621935216d FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: interview_questions fk_rails_6d359c2f48; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_questions
    ADD CONSTRAINT fk_rails_6d359c2f48 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: job_application_events fk_rails_71ec7e0805; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_application_events
    ADD CONSTRAINT fk_rails_71ec7e0805 FOREIGN KEY (job_application_id) REFERENCES public.job_applications(id) ON DELETE CASCADE;


--
-- Name: hidden_interview_questions fk_rails_89d1705a87; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hidden_interview_questions
    ADD CONSTRAINT fk_rails_89d1705a87 FOREIGN KEY (interview_question_id) REFERENCES public.interview_questions(id) ON DELETE CASCADE;


--
-- Name: vacancy_skills fk_rails_95115605ff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacancy_skills
    ADD CONSTRAINT fk_rails_95115605ff FOREIGN KEY (vacancy_id) REFERENCES public.vacancies(id) ON DELETE CASCADE;


--
-- Name: company_outreaches fk_rails_958252ccbd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_outreaches
    ADD CONSTRAINT fk_rails_958252ccbd FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE RESTRICT;


--
-- Name: vacancy_postings fk_rails_b0f10a0fa4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacancy_postings
    ADD CONSTRAINT fk_rails_b0f10a0fa4 FOREIGN KEY (vacancy_id) REFERENCES public.vacancies(id) ON DELETE CASCADE;


--
-- Name: job_applications fk_rails_e30bd575ce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_applications
    ADD CONSTRAINT fk_rails_e30bd575ce FOREIGN KEY (via_posting_id) REFERENCES public.vacancy_postings(id) ON DELETE SET NULL;


--
-- Name: vacancies fk_rails_f571abc0d6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vacancies
    ADD CONSTRAINT fk_rails_f571abc0d6 FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE RESTRICT;


--
-- Name: user_skills fk_rails_fe61b6a893; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_skills
    ADD CONSTRAINT fk_rails_fe61b6a893 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260731102548'),
('20260731095335'),
('20260731095334'),
('20260730154356'),
('20260730154355'),
('20260730112856'),
('20260730112855'),
('20260730112854'),
('20260730112853'),
('20260730112852'),
('20260730112851'),
('20260730112850'),
('20260730112849'),
('20260730112304'),
('20260730112303'),
('20260730101721'),
('20260730101720');

