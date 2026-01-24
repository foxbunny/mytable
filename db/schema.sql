\restrict dbmate

-- Dumped from database version 18.1 (Ubuntu 18.1-1.pgdg24.04+2)
-- Dumped by pg_dump version 18.1 (Ubuntu 18.1-1.pgdg24.04+2)

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

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: update_restaurant_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_restaurant_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	new.updated_at = now();
	return new;
end;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_users (
    id integer NOT NULL,
    username text NOT NULL,
    password_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: admin_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_users_id_seq OWNED BY public.admin_users.id;


--
-- Name: customer_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_session (
    id integer NOT NULL,
    token text DEFAULT (gen_random_uuid())::text NOT NULL,
    reservation_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '24:00:00'::interval) NOT NULL
);


--
-- Name: customer_session_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.customer_session_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customer_session_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.customer_session_id_seq OWNED BY public.customer_session.id;


--
-- Name: floorplan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.floorplan (
    id integer NOT NULL,
    name text NOT NULL,
    image_path text NOT NULL,
    image_width integer NOT NULL,
    image_height integer NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: floorplan_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.floorplan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: floorplan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.floorplan_id_seq OWNED BY public.floorplan.id;


--
-- Name: floorplan_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.floorplan_table (
    id integer NOT NULL,
    floorplan_id integer NOT NULL,
    name text NOT NULL,
    capacity integer DEFAULT 2 NOT NULL,
    notes text,
    x_pct numeric(5,4) NOT NULL,
    y_pct numeric(5,4) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT floorplan_table_x_pct_check CHECK (((x_pct >= (0)::numeric) AND (x_pct <= (1)::numeric))),
    CONSTRAINT floorplan_table_y_pct_check CHECK (((y_pct >= (0)::numeric) AND (y_pct <= (1)::numeric)))
);


--
-- Name: floorplan_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.floorplan_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: floorplan_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.floorplan_table_id_seq OWNED BY public.floorplan_table.id;


--
-- Name: reservation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservation (
    id integer NOT NULL,
    guest_name text NOT NULL,
    guest_phone text,
    guest_email text,
    party_size integer NOT NULL,
    reservation_date date NOT NULL,
    reservation_time time without time zone NOT NULL,
    duration_minutes integer DEFAULT 90 NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    source text DEFAULT 'online'::text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reservation_party_size_check CHECK ((party_size >= 1)),
    CONSTRAINT reservation_source_check CHECK ((source = ANY (ARRAY['online'::text, 'phone'::text, 'walk_in'::text]))),
    CONSTRAINT reservation_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'declined'::text, 'completed'::text, 'no_show'::text, 'cancelled'::text])))
);


--
-- Name: reservation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reservation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reservation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reservation_id_seq OWNED BY public.reservation.id;


--
-- Name: reservation_notification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservation_notification (
    id integer NOT NULL,
    reservation_id integer NOT NULL,
    code text NOT NULL,
    admin_message text,
    delivered boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: reservation_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reservation_notification_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reservation_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reservation_notification_id_seq OWNED BY public.reservation_notification.id;


--
-- Name: reservation_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservation_table (
    reservation_id integer NOT NULL,
    floorplan_table_id integer NOT NULL
);


--
-- Name: restaurant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.restaurant (
    id integer DEFAULT 1 NOT NULL,
    name text NOT NULL,
    address text,
    phone text,
    working_hours jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT restaurant_id_check CHECK ((id = 1))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: table_block; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.table_block (
    id integer NOT NULL,
    floorplan_table_id integer NOT NULL,
    blocked_at timestamp with time zone DEFAULT now() NOT NULL,
    notes text
);


--
-- Name: table_block_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.table_block_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: table_block_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.table_block_id_seq OWNED BY public.table_block.id;


--
-- Name: admin_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users ALTER COLUMN id SET DEFAULT nextval('public.admin_users_id_seq'::regclass);


--
-- Name: customer_session id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_session ALTER COLUMN id SET DEFAULT nextval('public.customer_session_id_seq'::regclass);


--
-- Name: floorplan id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.floorplan ALTER COLUMN id SET DEFAULT nextval('public.floorplan_id_seq'::regclass);


--
-- Name: floorplan_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.floorplan_table ALTER COLUMN id SET DEFAULT nextval('public.floorplan_table_id_seq'::regclass);


--
-- Name: reservation id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation ALTER COLUMN id SET DEFAULT nextval('public.reservation_id_seq'::regclass);


--
-- Name: reservation_notification id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_notification ALTER COLUMN id SET DEFAULT nextval('public.reservation_notification_id_seq'::regclass);


--
-- Name: table_block id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_block ALTER COLUMN id SET DEFAULT nextval('public.table_block_id_seq'::regclass);


--
-- Name: admin_users admin_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_pkey PRIMARY KEY (id);


--
-- Name: admin_users admin_users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_username_key UNIQUE (username);


--
-- Name: customer_session customer_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_session
    ADD CONSTRAINT customer_session_pkey PRIMARY KEY (id);


--
-- Name: customer_session customer_session_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_session
    ADD CONSTRAINT customer_session_token_key UNIQUE (token);


--
-- Name: floorplan floorplan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.floorplan
    ADD CONSTRAINT floorplan_pkey PRIMARY KEY (id);


--
-- Name: floorplan_table floorplan_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.floorplan_table
    ADD CONSTRAINT floorplan_table_pkey PRIMARY KEY (id);


--
-- Name: table_block one_active_block_per_table; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_block
    ADD CONSTRAINT one_active_block_per_table UNIQUE (floorplan_table_id);


--
-- Name: reservation_notification reservation_notification_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_notification
    ADD CONSTRAINT reservation_notification_pkey PRIMARY KEY (id);


--
-- Name: reservation reservation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_pkey PRIMARY KEY (id);


--
-- Name: reservation_table reservation_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_table
    ADD CONSTRAINT reservation_table_pkey PRIMARY KEY (reservation_id, floorplan_table_id);


--
-- Name: restaurant restaurant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurant
    ADD CONSTRAINT restaurant_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: table_block table_block_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_block
    ADD CONSTRAINT table_block_pkey PRIMARY KEY (id);


--
-- Name: customer_session_reservation_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX customer_session_reservation_idx ON public.customer_session USING btree (reservation_id);


--
-- Name: customer_session_token_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX customer_session_token_idx ON public.customer_session USING btree (token);


--
-- Name: floorplan_table_floorplan_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX floorplan_table_floorplan_id_idx ON public.floorplan_table USING btree (floorplan_id);


--
-- Name: reservation_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservation_date_idx ON public.reservation USING btree (reservation_date);


--
-- Name: reservation_date_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservation_date_status_idx ON public.reservation USING btree (reservation_date, status);


--
-- Name: reservation_notification_reservation_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservation_notification_reservation_idx ON public.reservation_notification USING btree (reservation_id);


--
-- Name: reservation_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservation_status_idx ON public.reservation USING btree (status);


--
-- Name: reservation_table_table_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservation_table_table_idx ON public.reservation_table USING btree (floorplan_table_id);


--
-- Name: reservation reservation_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER reservation_updated_at BEFORE UPDATE ON public.reservation FOR EACH ROW EXECUTE FUNCTION public.update_restaurant_timestamp();


--
-- Name: restaurant restaurant_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER restaurant_updated_at BEFORE UPDATE ON public.restaurant FOR EACH ROW EXECUTE FUNCTION public.update_restaurant_timestamp();


--
-- Name: customer_session customer_session_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_session
    ADD CONSTRAINT customer_session_reservation_id_fkey FOREIGN KEY (reservation_id) REFERENCES public.reservation(id) ON DELETE CASCADE;


--
-- Name: floorplan_table floorplan_table_floorplan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.floorplan_table
    ADD CONSTRAINT floorplan_table_floorplan_id_fkey FOREIGN KEY (floorplan_id) REFERENCES public.floorplan(id) ON DELETE CASCADE;


--
-- Name: reservation_notification reservation_notification_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_notification
    ADD CONSTRAINT reservation_notification_reservation_id_fkey FOREIGN KEY (reservation_id) REFERENCES public.reservation(id) ON DELETE CASCADE;


--
-- Name: reservation_table reservation_table_floorplan_table_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_table
    ADD CONSTRAINT reservation_table_floorplan_table_id_fkey FOREIGN KEY (floorplan_table_id) REFERENCES public.floorplan_table(id) ON DELETE CASCADE;


--
-- Name: reservation_table reservation_table_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_table
    ADD CONSTRAINT reservation_table_reservation_id_fkey FOREIGN KEY (reservation_id) REFERENCES public.reservation(id) ON DELETE CASCADE;


--
-- Name: table_block table_block_floorplan_table_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_block
    ADD CONSTRAINT table_block_floorplan_table_id_fkey FOREIGN KEY (floorplan_table_id) REFERENCES public.floorplan_table(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20260114155206'),
    ('20260116133141'),
    ('20260117162152'),
    ('20260118123020'),
    ('20260119193812'),
    ('20260122100000');
