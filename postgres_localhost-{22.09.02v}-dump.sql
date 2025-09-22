--
-- PostgreSQL database dump
--

\restrict NAoPVUsQsaDYyTM5pc3YgNA66ogeQTKeYpbvQhqgGqaRzQPaXbzJeAMwGJRNgjI

-- Dumped from database version 15.5 (Debian 15.5-1.pgdg120+1)
-- Dumped by pg_dump version 15.14 (Ubuntu 15.14-1.pgdg22.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: postgres; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE postgres WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'tr_TR.utf8';


ALTER DATABASE postgres OWNER TO postgres;

\unrestrict NAoPVUsQsaDYyTM5pc3YgNA66ogeQTKeYpbvQhqgGqaRzQPaXbzJeAMwGJRNgjI
\connect postgres
\restrict NAoPVUsQsaDYyTM5pc3YgNA66ogeQTKeYpbvQhqgGqaRzQPaXbzJeAMwGJRNgjI

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: DATABASE postgres; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE postgres IS 'default administrative connection database';


--
-- Name: _overlaps(timestamp without time zone, timestamp without time zone, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public._overlaps(ts1_start timestamp without time zone, ts1_end timestamp without time zone, ts2_start timestamp without time zone, ts2_end timestamp without time zone) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
SELECT ts1_start < ts2_end AND ts2_start < ts1_end;
$$;


ALTER FUNCTION public._overlaps(ts1_start timestamp without time zone, ts1_end timestamp without time zone, ts2_start timestamp without time zone, ts2_end timestamp without time zone) OWNER TO postgres;

--
-- Name: trg_airport_capacity(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_airport_capacity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    dep_conc int; arr_conc int;
    dep_cap  int; arr_cap  int;
BEGIN
    SELECT ucak_kapasitesi INTO dep_cap FROM public.airport WHERE id = NEW.departure_airport_id;
    SELECT ucak_kapasitesi INTO arr_cap FROM public.airport WHERE id = NEW.arrival_airport_id;

    -- any flight touching the airport within overlap window (arrival or departure)
    SELECT COUNT(*) INTO dep_conc
    FROM public.flights f
    WHERE (f.departure_airport_id = NEW.departure_airport_id OR f.arrival_airport_id = NEW.departure_airport_id)
      AND f.id <> COALESCE(NEW.id, -1)
      AND public._overlaps(NEW.departure_ts, NEW.arrival_ts, f.departure_ts, f.arrival_ts);

    SELECT COUNT(*) INTO arr_conc
    FROM public.flights f
    WHERE (f.departure_airport_id = NEW.arrival_airport_id OR f.arrival_airport_id = NEW.arrival_airport_id)
      AND f.id <> COALESCE(NEW.id, -1)
      AND public._overlaps(NEW.departure_ts, NEW.arrival_ts, f.departure_ts, f.arrival_ts);

    IF dep_conc >= dep_cap THEN
        RAISE EXCEPTION 'Kalkış havalimanında eşzamanlı uçak sayısı kapasiteyi aşıyor.';
    END IF;
    IF arr_conc >= arr_cap THEN
        RAISE EXCEPTION 'Varış havalimanında eşzamanlı uçak sayısı kapasiteyi aşıyor.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_airport_capacity() OWNER TO postgres;

--
-- Name: trg_person_overlap(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_person_overlap() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE has_overlap boolean;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM public.flight_person fp
                 JOIN public.flights f  ON f.id  = fp.flight_id
                 JOIN public.flights nf ON nf.id = NEW.flight_id
        WHERE fp.person_id = NEW.person_id
          AND public._overlaps(f.departure_ts, f.arrival_ts, nf.departure_ts, nf.arrival_ts)
    ) INTO has_overlap;

    IF has_overlap THEN
        RAISE EXCEPTION 'Aynı kişi aynı zaman aralığında birden fazla uçuş yapamaz.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_person_overlap() OWNER TO postgres;

--
-- Name: trg_plane_overlap(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_plane_overlap() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.flights f
        WHERE f.plane_id = NEW.plane_id
          AND f.id <> COALESCE(NEW.id, -1)
          AND public._overlaps(NEW.departure_ts, NEW.arrival_ts, f.departure_ts, f.arrival_ts)
    ) THEN
        RAISE EXCEPTION 'Aynı uçak aynı zaman aralığında birden fazla uçuş yapamaz.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_plane_overlap() OWNER TO postgres;

--
-- Name: trg_runway_capacity(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_runway_capacity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    dep_ops int; arr_ops int;
    dep_pist int; arr_pist int;
BEGIN
    SELECT pist_sayisi INTO dep_pist FROM public.airport WHERE id = NEW.departure_airport_id;
    SELECT pist_sayisi INTO arr_pist FROM public.airport WHERE id = NEW.arrival_airport_id;

    SELECT COUNT(*) INTO dep_ops
    FROM public.flights f
    WHERE f.departure_airport_id = NEW.departure_airport_id
      AND f.id <> COALESCE(NEW.id, -1)
      AND public._overlaps(NEW.departure_ts, NEW.arrival_ts, f.departure_ts, f.arrival_ts);

    SELECT COUNT(*) INTO arr_ops
    FROM public.flights f
    WHERE f.arrival_airport_id = NEW.arrival_airport_id
      AND f.id <> COALESCE(NEW.id, -1)
      AND public._overlaps(NEW.departure_ts, NEW.arrival_ts, f.departure_ts, f.arrival_ts);

    IF dep_ops >= dep_pist THEN
        RAISE EXCEPTION 'Kalkış havalimanında eşzamanlı operasyon sayısı pist sayısını aşıyor.';
    END IF;
    IF arr_ops >= arr_pist THEN
        RAISE EXCEPTION 'Varış havalimanında eşzamanlı operasyon sayısı pist sayısını aşıyor.';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_runway_capacity() OWNER TO postgres;

--
-- Name: airport_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.airport_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.airport_id_seq OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: airport; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.airport (
    id integer DEFAULT nextval('public.airport_id_seq'::regclass) NOT NULL,
    name character varying(100) NOT NULL,
    pist_sayisi integer NOT NULL,
    ucak_kapasitesi integer NOT NULL
);


ALTER TABLE public.airport OWNER TO postgres;

--
-- Name: flight_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.flight_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.flight_id_seq OWNER TO postgres;

--
-- Name: flight_person_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.flight_person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.flight_person_id_seq OWNER TO postgres;

--
-- Name: flight_person; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.flight_person (
    id integer DEFAULT nextval('public.flight_person_id_seq'::regclass) NOT NULL,
    flight_id integer NOT NULL,
    person_id integer NOT NULL
);


ALTER TABLE public.flight_person OWNER TO postgres;

--
-- Name: flights_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.flights_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.flights_id_seq OWNER TO postgres;

--
-- Name: flights; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.flights (
    id integer DEFAULT nextval('public.flights_id_seq'::regclass) NOT NULL,
    departure_airport_id integer NOT NULL,
    arrival_airport_id integer NOT NULL,
    plane_id integer NOT NULL,
    departure_ts timestamp without time zone NOT NULL,
    arrival_ts timestamp without time zone NOT NULL
);


ALTER TABLE public.flights OWNER TO postgres;

--
-- Name: person_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.person_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.person_id_seq OWNER TO postgres;

--
-- Name: person; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.person (
    id integer DEFAULT nextval('public.person_id_seq'::regclass) NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    gender character varying(10),
    age integer
);


ALTER TABLE public.person OWNER TO postgres;

--
-- Name: plane_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.plane_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.plane_id_seq OWNER TO postgres;

--
-- Name: plane; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.plane (
    id integer DEFAULT nextval('public.plane_id_seq'::regclass) NOT NULL,
    brand character varying(50),
    model character varying(50) NOT NULL,
    capacity integer NOT NULL,
    year integer
);


ALTER TABLE public.plane OWNER TO postgres;

--
-- Data for Name: airport; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.airport (id, name, pist_sayisi, ucak_kapasitesi) FROM stdin;
1	Atatürk Havalimanı	5	50
2	Sabiha Gökçen Havalimanı	5	50
3	Esenboğa Havalimanı	5	50
\.


--
-- Data for Name: flight_person; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.flight_person (id, flight_id, person_id) FROM stdin;
1	1	2
2	3	1
3	3	2
4	3	3
5	3	4
6	4	7
\.


--
-- Data for Name: flights; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.flights (id, departure_airport_id, arrival_airport_id, plane_id, departure_ts, arrival_ts) FROM stdin;
1	2	1	1	2025-09-11 16:28:00	2025-09-11 17:28:00
2	1	2	2	2025-09-11 10:01:00	2025-09-11 12:01:00
3	2	3	3	2025-09-15 12:05:00	2025-09-15 14:05:00
4	1	3	2	2025-09-19 10:20:00	2025-09-19 12:20:00
\.


--
-- Data for Name: person; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.person (id, first_name, last_name, gender, age) FROM stdin;
1	Oguzhan	Veli	Erkek	25
2	Selin	Dogan	Kadın	36
3	Ali	Yılmaz	Erkek	32
4	Oğuzhan	Tanrıverdi	Erkek	29
5	Mehmet	Emin	Erkek	24
6	Büşra	Solmaz	Kadın	25
7	Fatma	ŞAH,N	Kadın	29
\.


--
-- Data for Name: plane; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.plane (id, brand, model, capacity, year) FROM stdin;
1	Boeing	Boeing-737	180	2020
2	Airbus	Airbus-A320	150	2022
3	Bombardier	Bombardier-CS300	120	2024
\.


--
-- Name: airport_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.airport_id_seq', 3, true);


--
-- Name: flight_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.flight_id_seq', 2, true);


--
-- Name: flight_person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.flight_person_id_seq', 6, true);


--
-- Name: flights_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.flights_id_seq', 4, true);


--
-- Name: person_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.person_id_seq', 7, true);


--
-- Name: plane_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.plane_id_seq', 3, true);


--
-- Name: airport airport_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.airport
    ADD CONSTRAINT airport_pkey PRIMARY KEY (id);


--
-- Name: flight_person flight_person_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.flight_person
    ADD CONSTRAINT flight_person_pkey PRIMARY KEY (id);


--
-- Name: flights flights_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.flights
    ADD CONSTRAINT flights_pkey PRIMARY KEY (id);


--
-- Name: person person_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.person
    ADD CONSTRAINT person_pkey PRIMARY KEY (id);


--
-- Name: plane plane_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.plane
    ADD CONSTRAINT plane_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

\unrestrict NAoPVUsQsaDYyTM5pc3YgNA66ogeQTKeYpbvQhqgGqaRzQPaXbzJeAMwGJRNgjI

