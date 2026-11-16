CREATE DATABASE IF NOT EXISTS fleet_logistics CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE fleet_logistics;

CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(254) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('admin','operations') NOT NULL DEFAULT 'operations',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS app_sessions (
  token_hash BINARY(32) NOT NULL PRIMARY KEY,
  user_id BIGINT UNSIGNED NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_sessions_expiry (expires_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS drivers (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  license_number VARCHAR(40) NOT NULL UNIQUE,
  phone VARCHAR(32) NOT NULL,
  email VARCHAR(254) NULL UNIQUE,
  license_expires_on DATE NOT NULL,
  status ENUM('available','on_trip','on_leave','inactive') NOT NULL DEFAULT 'available',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_driver_name CHECK (CHAR_LENGTH(TRIM(full_name)) > 1)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vehicles (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  registration_number VARCHAR(24) NOT NULL UNIQUE,
  vehicle_type ENUM('van','truck','tractor','trailer') NOT NULL,
  make VARCHAR(60) NOT NULL,
  model VARCHAR(60) NOT NULL,
  year SMALLINT UNSIGNED NOT NULL,
  capacity_kg DECIMAL(10,2) NOT NULL,
  odometer_km INT UNSIGNED NOT NULL DEFAULT 0,
  status ENUM('available','on_trip','maintenance','inactive') NOT NULL DEFAULT 'available',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_vehicle_year CHECK (year BETWEEN 1980 AND 2100),
  CONSTRAINT chk_vehicle_capacity CHECK (capacity_kg > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS trips (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  trip_code VARCHAR(24) NOT NULL UNIQUE,
  vehicle_id BIGINT UNSIGNED NULL,
  driver_id BIGINT UNSIGNED NULL,
  status ENUM('planned','assigned','in_progress','completed','cancelled') NOT NULL DEFAULT 'planned',
  start_location VARCHAR(180) NOT NULL,
  end_location VARCHAR(180) NOT NULL,
  planned_start DATETIME NOT NULL,
  actual_start DATETIME NULL,
  actual_end DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_trips_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE RESTRICT,
  CONSTRAINT fk_trips_driver FOREIGN KEY (driver_id) REFERENCES drivers(id) ON DELETE RESTRICT,
  CONSTRAINT chk_trip_assignment CHECK ((vehicle_id IS NULL AND driver_id IS NULL AND status = 'planned') OR (vehicle_id IS NOT NULL AND driver_id IS NOT NULL AND status <> 'planned')),
  INDEX idx_trips_status_start (status, planned_start),
  INDEX idx_trips_vehicle_status (vehicle_id, status),
  INDEX idx_trips_driver_status (driver_id, status)
) ENGINE=InnoDB;
