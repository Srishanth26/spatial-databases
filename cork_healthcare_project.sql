-- =====================================================
-- CS621 SPATIAL DATABASES PROJECT
-- Healthcare Accessibility in Cork, Ireland
-- Student: Vemula Srishanth Goud
-- Roll.No:25251798
-- Date: January 2026
-- =====================================================

-- Enable PostGIS Extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- =====================================================
-- TABLE CREATION
-- =====================================================

-- Create Hospitals Table
DROP TABLE IF EXISTS cork_hospitals CASCADE;
CREATE TABLE cork_hospitals (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    latitude DECIMAL(10, 6),
    longitude DECIMAL(10, 6),
    type VARCHAR(50)
);

-- Create Pharmacies Table
DROP TABLE IF EXISTS cork_pharmacies CASCADE;
CREATE TABLE cork_pharmacies (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    latitude DECIMAL(10, 6),
    longitude DECIMAL(10, 6),
    type VARCHAR(50)
);

-- Create Residential Areas Table
DROP TABLE IF EXISTS cork_residential CASCADE;
CREATE TABLE cork_residential (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    latitude DECIMAL(10, 6),
    longitude DECIMAL(10, 6),
    population INTEGER
);

-- =====================================================
-- DATA INSERTION
-- =====================================================

-- Insert Hospital Data
INSERT INTO cork_hospitals (name, latitude, longitude, type) VALUES
('Cork University Hospital', 51.8875, -8.4944, 'General Hospital'),
('Mercy University Hospital', 51.8956, -8.4778, 'General Hospital'),
('South Infirmary Victoria Hospital', 51.8903, -8.4819, 'General Hospital'),
('Bon Secours Hospital Cork', 51.8931, -8.4925, 'Private Hospital'),
('Mater Private Hospital Cork', 51.9033, -8.4689, 'Private Hospital');

-- Insert Pharmacy Data
INSERT INTO cork_pharmacies (name, latitude, longitude, type) VALUES
('Boots Pharmacy Patrick Street', 51.8986, -8.4748, 'Chain Pharmacy'),
('Lloyds Pharmacy Oliver Plunkett St', 51.8978, -8.4722, 'Chain Pharmacy'),
('Careplus Pharmacy Wilton', 51.8833, -8.4906, 'Independent Pharmacy'),
('Hickey Pharmacy Douglas', 51.8764, -8.4344, 'Independent Pharmacy'),
('Boots Pharmacy Mahon Point', 51.8892, -8.3981, 'Chain Pharmacy'),
('McCabes Pharmacy Blackpool', 51.9103, -8.4656, 'Chain Pharmacy'),
('Mulcahy Pharmacy Ballincollig', 51.8875, -8.5856, 'Independent Pharmacy'),
('Phelan Pharmacy Glanmire', 51.9086, -8.4019, 'Independent Pharmacy'),
('Sam McCauley Pharmacy', 51.8969, -8.4869, 'Chain Pharmacy'),
('Total Health Pharmacy Bishopstown', 51.8822, -8.5203, 'Independent Pharmacy');

-- Insert Residential Areas Data
INSERT INTO cork_residential (name, latitude, longitude, population) VALUES
('Cork City Centre', 51.8985, -8.4756, 5200),
('Blackpool', 51.9103, -8.4656, 8500),
('Douglas', 51.8764, -8.4344, 12500),
('Ballincollig', 51.8875, -8.5856, 18500),
('Bishopstown', 51.8822, -8.5203, 14000),
('Wilton', 51.8833, -8.4906, 9500),
('Mahon', 51.8892, -8.3981, 11000),
('Glanmire', 51.9086, -8.4019, 16000),
('Turner''s Cross', 51.8867, -8.4833, 7500),
('Togher', 51.8789, -8.4922, 8000);

-- =====================================================
-- ADD GEOMETRY COLUMNS
-- =====================================================

-- Add geometry column to hospitals
ALTER TABLE cork_hospitals ADD COLUMN geom GEOMETRY(Point, 4326);
UPDATE cork_hospitals SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);

-- Add geometry column to pharmacies
ALTER TABLE cork_pharmacies ADD COLUMN geom GEOMETRY(Point, 4326);
UPDATE cork_pharmacies SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);

-- Add geometry column to residential areas
ALTER TABLE cork_residential ADD COLUMN geom GEOMETRY(Point, 4326);
UPDATE cork_residential SET geom = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);

-- =====================================================
-- CREATE SPATIAL INDEXES
-- =====================================================

CREATE INDEX idx_hospitals_geom ON cork_hospitals USING GIST(geom);
CREATE INDEX idx_pharmacies_geom ON cork_pharmacies USING GIST(geom);
CREATE INDEX idx_residential_geom ON cork_residential USING GIST(geom);

-- =====================================================
-- SPATIAL ANALYSIS QUERIES
-- =====================================================

-- QUERY 1: Find distance from each residential area to nearest hospital
SELECT 
    r.name AS residential_area,
    r.population,
    h.name AS nearest_hospital,
    ROUND(ST_Distance(r.geom::geography, h.geom::geography)::numeric, 0) AS distance_meters
FROM cork_residential r
CROSS JOIN LATERAL (
    SELECT name, geom
    FROM cork_hospitals
    ORDER BY r.geom <-> geom
    LIMIT 1
) h
ORDER BY distance_meters DESC;

-- QUERY 2: Find distance from each residential area to nearest pharmacy
SELECT 
    r.name AS residential_area,
    r.population,
    p.name AS nearest_pharmacy,
    ROUND(ST_Distance(r.geom::geography, p.geom::geography)::numeric, 0) AS distance_meters
FROM cork_residential r
CROSS JOIN LATERAL (
    SELECT name, geom
    FROM cork_pharmacies
    ORDER BY r.geom <-> geom
    LIMIT 1
) p
ORDER BY distance_meters DESC;

-- QUERY 3: Count healthcare facilities within 2km of each residential area
SELECT 
    r.name AS residential_area,
    r.population,
    (SELECT COUNT(*) FROM cork_hospitals h 
     WHERE ST_DWithin(r.geom::geography, h.geom::geography, 2000)) AS hospitals_within_2km,
    (SELECT COUNT(*) FROM cork_pharmacies p 
     WHERE ST_DWithin(r.geom::geography, p.geom::geography, 2000)) AS pharmacies_within_2km
FROM cork_residential r
ORDER BY hospitals_within_2km ASC, pharmacies_within_2km ASC;

-- =====================================================
-- CREATE BUFFER ZONES FOR VISUALIZATION
-- =====================================================

-- Create hospital buffer zones (1km, 2km, 3km)
DROP TABLE IF EXISTS hospital_buffers;
CREATE TABLE hospital_buffers AS
SELECT 
    h.id,
    h.name,
    '1km' AS buffer_size,
    ST_Buffer(h.geom::geography, 1000)::geometry AS geom
FROM cork_hospitals h
UNION ALL
SELECT 
    h.id,
    h.name,
    '2km' AS buffer_size,
    ST_Buffer(h.geom::geography, 2000)::geometry AS geom
FROM cork_hospitals h
UNION ALL
SELECT 
    h.id,
    h.name,
    '3km' AS buffer_size,
    ST_Buffer(h.geom::geography, 3000)::geometry AS geom
FROM cork_hospitals h;

-- Create pharmacy buffer zones (500m, 1km)
DROP TABLE IF EXISTS pharmacy_buffers;
CREATE TABLE pharmacy_buffers AS
SELECT 
    p.id,
    p.name,
    '500m' AS buffer_size,
    ST_Buffer(p.geom::geography, 500)::geometry AS geom
FROM cork_pharmacies p
UNION ALL
SELECT 
    p.id,
    p.name,
    '1km' AS buffer_size,
    ST_Buffer(p.geom::geography, 1000)::geometry AS geom
FROM cork_pharmacies p;

-- =====================================================
-- CREATE HEALTHCARE ACCESSIBILITY VIEW
-- =====================================================

DROP VIEW IF EXISTS healthcare_accessibility;
CREATE VIEW healthcare_accessibility AS
SELECT 
    r.name AS residential_area,
    r.population,
    h.name AS nearest_hospital,
    ROUND(ST_Distance(r.geom::geography, h.geom::geography)::numeric, 0) AS hospital_distance_m,
    p.name AS nearest_pharmacy,
    ROUND(ST_Distance(r.geom::geography, p.geom::geography)::numeric, 0) AS pharmacy_distance_m,
    (SELECT COUNT(*) FROM cork_hospitals 
     WHERE ST_DWithin(r.geom::geography, geom::geography, 2000)) AS hospitals_within_2km,
    (SELECT COUNT(*) FROM cork_pharmacies 
     WHERE ST_DWithin(r.geom::geography, geom::geography, 2000)) AS pharmacies_within_2km,
    r.geom
FROM cork_residential r
CROSS JOIN LATERAL (
    SELECT name, geom FROM cork_hospitals ORDER BY r.geom <-> geom LIMIT 1
) h
CROSS JOIN LATERAL (
    SELECT name, geom FROM cork_pharmacies ORDER BY r.geom <-> geom LIMIT 1
) p
ORDER BY hospital_distance_m DESC;

-- =====================================================
-- VIEW FINAL RESULTS
-- =====================================================

SELECT 
    residential_area,
    population,
    nearest_hospital,
    hospital_distance_m,
    nearest_pharmacy,
    pharmacy_distance_m,
    hospitals_within_2km,
    pharmacies_within_2km
FROM healthcare_accessibility;