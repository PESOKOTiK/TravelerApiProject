-- PostgreSQL Database Schema for TravelerAPI (Lab 1 DDS)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DROP TABLE IF EXISTS locations CASCADE;
DROP TABLE IF EXISTS travel_plans CASCADE;

CREATE TABLE travel_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL CHECK (char_length(trim(title)) > 0),
    description TEXT NULL,
    start_date DATE NULL,
    end_date DATE NULL,
    budget DECIMAL(10, 2) NULL CHECK (budget >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD' CHECK (char_length(currency) = 3),
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_travel_plan_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE TABLE locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    travel_plan_id UUID NOT NULL REFERENCES travel_plans(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL CHECK (char_length(trim(name)) > 0),
    address TEXT NULL,
    latitude DECIMAL(10, 6) NULL CHECK (latitude >= -90 AND latitude <= 90),
    longitude DECIMAL(11, 6) NULL CHECK (longitude >= -180 AND longitude <= 180),
    visit_order INTEGER NOT NULL CHECK (visit_order > 0),
    arrival_date TIMESTAMPTZ NULL,
    departure_date TIMESTAMPTZ NULL,
    budget DECIMAL(10, 2) NULL CHECK (budget >= 0),
    notes TEXT NULL,
    version INTEGER NOT NULL DEFAULT 1 CHECK (version >= 1),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_location_dates CHECK (departure_date IS NULL OR arrival_date IS NULL OR departure_date >= arrival_date),
    CONSTRAINT uq_plan_visit_order UNIQUE (travel_plan_id, visit_order) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX idx_locations_travel_plan_id ON locations(travel_plan_id);

-- Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_travel_plans_updated_at
BEFORE UPDATE ON travel_plans
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
