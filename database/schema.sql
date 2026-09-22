PRAGMA foreign_keys = ON;

-- 1. Drop existing objects
DROP VIEW IF EXISTS view_clinic_revenue_summary;
DROP TRIGGER IF EXISTS trg_audit_appointment_cancellation;
DROP TRIGGER IF EXISTS trg_deduct_medicine_inventory;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS billings;
DROP TABLE IF EXISTS prescription_items;
DROP TABLE IF EXISTS medicines;
DROP TABLE IF EXISTS prescriptions;
DROP TABLE IF EXISTS appointments;
DROP TABLE IF EXISTS doctor_schedules;
DROP TABLE IF EXISTS doctors;
DROP TABLE IF EXISTS patients;
DROP TABLE IF EXISTS departments;

-- 2. DDL Definitions
CREATE TABLE departments (
    dept_id INTEGER PRIMARY KEY AUTOINCREMENT,
    dept_name TEXT NOT NULL UNIQUE,
    building_block TEXT NOT NULL
);

CREATE TABLE doctors (
    doctor_id INTEGER PRIMARY KEY AUTOINCREMENT,
    dept_id INTEGER NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    consultation_fee REAL NOT NULL CHECK(consultation_fee >= 0.0),
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id) ON DELETE RESTRICT
);

CREATE TABLE patients (
    patient_id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone_number TEXT NOT NULL,
    blood_group TEXT NOT NULL CHECK(blood_group IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE doctor_schedules (
    schedule_id INTEGER PRIMARY KEY AUTOINCREMENT,
    doctor_id INTEGER NOT NULL,
    day_of_week TEXT NOT NULL CHECK(day_of_week IN ('MONDAY','TUESDAY','WEDNESDAY','THURSDAY','FRIDAY','SATURDAY')),
    shift_start TEXT NOT NULL,
    shift_end TEXT NOT NULL,
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE
);

CREATE TABLE appointments (
    appointment_id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL,
    doctor_id INTEGER NOT NULL,
    appointment_date TEXT NOT NULL,
    time_slot TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'SCHEDULED' CHECK(status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE CASCADE,
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE CASCADE,
    UNIQUE(doctor_id, appointment_date, time_slot)
);

CREATE TABLE prescriptions (
    prescription_id INTEGER PRIMARY KEY AUTOINCREMENT,
    appointment_id INTEGER NOT NULL UNIQUE,
    diagnosis_notes TEXT NOT NULL,
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE
);

CREATE TABLE medicines (
    medicine_id INTEGER PRIMARY KEY AUTOINCREMENT,
    medicine_name TEXT NOT NULL UNIQUE,
    unit_price REAL NOT NULL CHECK(unit_price >= 0.0),
    stock_quantity INTEGER NOT NULL CHECK(stock_quantity >= 0),
    reorder_threshold INTEGER NOT NULL DEFAULT 20
);

CREATE TABLE prescription_items (
    item_id INTEGER PRIMARY KEY AUTOINCREMENT,
    prescription_id INTEGER NOT NULL,
    medicine_id INTEGER NOT NULL,
    prescribed_units INTEGER NOT NULL CHECK(prescribed_units > 0),
    dosage_instructions TEXT NOT NULL,
    FOREIGN KEY (prescription_id) REFERENCES prescriptions(prescription_id) ON DELETE CASCADE,
    FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id) ON DELETE RESTRICT,
    UNIQUE(prescription_id, medicine_id)
);

CREATE TABLE billings (
    bill_id INTEGER PRIMARY KEY AUTOINCREMENT,
    appointment_id INTEGER NOT NULL UNIQUE,
    consultation_amount REAL NOT NULL CHECK(consultation_amount >= 0.0),
    medicine_amount REAL NOT NULL DEFAULT 0.0 CHECK(medicine_amount >= 0.0),
    total_amount REAL NOT NULL CHECK(total_amount >= 0.0),
    payment_status TEXT NOT NULL DEFAULT 'PENDING' CHECK(payment_status IN ('PENDING', 'PAID')),
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE CASCADE
);

CREATE TABLE audit_logs (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,
    record_id INTEGER NOT NULL,
    actor_info TEXT NOT NULL,
    occurred_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    log_details TEXT NOT NULL
);

-- Indexes for performance
CREATE INDEX idx_appointments_lookup ON appointments(doctor_id, appointment_date);
CREATE INDEX idx_prescriptions_appointment ON prescriptions(appointment_id);

-- Trigger 1: Guardrail deducting stock and preventing stockouts
CREATE TRIGGER trg_deduct_medicine_inventory
BEFORE INSERT ON prescription_items
BEGIN
    SELECT CASE
        WHEN (SELECT stock_quantity FROM medicines WHERE medicine_id = NEW.medicine_id) < NEW.prescribed_units
        THEN RAISE(ABORT, 'INVENTORY_SHORTAGE: Not enough stock to dispense this medicine.')
    END;
    UPDATE medicines 
    SET stock_quantity = stock_quantity - NEW.prescribed_units
    WHERE medicine_id = NEW.medicine_id;
END;

-- Trigger 2: Audit log for cancelled appointments
CREATE TRIGGER trg_audit_appointment_cancellation
AFTER UPDATE OF status ON appointments
WHEN NEW.status = 'CANCELLED' AND OLD.status != 'CANCELLED'
BEGIN
    INSERT INTO audit_logs (event_type, record_id, actor_info, log_details)
    VALUES (
        'APPOINTMENT_CANCELLED',
        NEW.appointment_id,
        'SYSTEM_TRIGGER',
        'Appointment cancelled for patient_id: ' || NEW.patient_id || ' with doctor_id: ' || NEW.doctor_id
    );
END;

-- Analytical View for Reporting
CREATE VIEW view_clinic_revenue_summary AS
SELECT 
    d.dept_name,
    COUNT(DISTINCT a.appointment_id) AS total_consultations,
    COALESCE(SUM(b.consultation_amount), 0.0) AS consultation_revenue,
    COALESCE(SUM(b.medicine_amount), 0.0) AS pharmacy_revenue,
    COALESCE(SUM(b.total_amount), 0.0) AS aggregate_gross_revenue
FROM departments d
LEFT JOIN doctors doc ON d.dept_id = doc.dept_id
LEFT JOIN appointments a ON doc.doctor_id = a.doctor_id AND a.status = 'COMPLETED'
LEFT JOIN billings b ON a.appointment_id = b.appointment_id AND b.payment_status = 'PAID'
GROUP BY d.dept_id, d.dept_name;