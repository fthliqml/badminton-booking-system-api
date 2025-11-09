-- Drop and Create Database
DROP DATABASE IF EXISTS badminton_court_management;
CREATE DATABASE badminton_court_management;
USE badminton_court_management;

-- =============================================
-- TABLE CREATION
-- =============================================

-- Drop tables if exist
DROP TABLE IF EXISTS bookings;
DROP TABLE IF EXISTS time_slots;
DROP TABLE IF EXISTS courts;
DROP TABLE IF EXISTS admins;

-- 1. ADMINS Table
CREATE TABLE admins (
    admin_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 2. COURTS Table
CREATE TABLE courts (
    court_id INT AUTO_INCREMENT PRIMARY KEY,
    court_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    price_per_session DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status ENUM('active', 'maintenance', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP  
);

-- 3. TIME_SLOTS Table
CREATE TABLE time_slots (
    slot_id INT AUTO_INCREMENT PRIMARY KEY,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    slot_name VARCHAR(50) NOT NULL,
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_time_slot (start_time, end_time), -- Cegah duplikasi rentang waktu yang sama
    INDEX idx_start_time (start_time),                  -- Mempercepat ORDER BY start_time (tanpa filter status)
    INDEX idx_status_start_time (status, start_time)    -- Mempercepat filter status='active' + ORDER BY/cek overlap
);

-- 4. BOOKINGS Table
CREATE TABLE bookings (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    court_id INT NOT NULL,
    slot_id INT NOT NULL,
    booking_date DATE NOT NULL,
    customer_name VARCHAR(100) NOT NULL,
    customer_phone VARCHAR(20),
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    payment_status ENUM('paid', 'unpaid', 'partial') DEFAULT 'unpaid',
    booking_status ENUM('confirmed', 'cancelled', 'completed') DEFAULT 'confirmed',
    notes TEXT,
    created_by INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (court_id) REFERENCES courts(court_id) ON DELETE CASCADE,
    FOREIGN KEY (slot_id) REFERENCES time_slots(slot_id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES admins(admin_id) ON DELETE CASCADE,
    
    UNIQUE KEY unique_booking (court_id, slot_id, booking_date), -- Cegah double booking kombinasi lapangan/slot/tanggal
    
    -- Indeks relevan sesuai pola query di prosedur:
    INDEX idx_court_booking_date (court_id, booking_date),       -- sp_get_booking_history (filter court + tanggal)
    INDEX idx_slot_booking_date (slot_id, booking_date),         -- validasi perubahan/hapus slot di masa depan
    INDEX idx_booking_date_status (booking_date, booking_status),-- hitung booking hari ini != 'cancelled';
    INDEX idx_created_by (created_by)                            -- join/filter berdasarkan admin pembuat
);

-- =============================================
-- FUNCTIONS
-- =============================================

-- Drop existing functions
DROP FUNCTION IF EXISTS is_slot_available;

-- Function: Check if slot is available
DELIMITER //
CREATE FUNCTION is_slot_available(
    p_court_id INT,
    p_slot_id INT,
    p_booking_date DATE
) RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE slot_count INT DEFAULT 0;
    
    SELECT COUNT(*) INTO slot_count
    FROM bookings 
    WHERE court_id = p_court_id 
      AND slot_id = p_slot_id 
      AND booking_date = p_booking_date
      AND booking_status != 'cancelled';
      
    RETURN (slot_count = 0);
END //
DELIMITER ;

-- =============================================
-- STORED PROCEDURES
-- =============================================

-- Login
DROP PROCEDURE IF EXISTS sp_admin_login;
-- Courts
DROP PROCEDURE IF EXISTS sp_get_all_courts;
DROP PROCEDURE IF EXISTS sp_get_court_by_id;
DROP PROCEDURE IF EXISTS sp_create_court;
DROP PROCEDURE IF EXISTS sp_update_court;
DROP PROCEDURE IF EXISTS sp_delete_court;
-- Time Slots
DROP PROCEDURE IF EXISTS sp_get_all_time_slots;
DROP PROCEDURE IF EXISTS sp_get_available_time_slots;
DROP PROCEDURE IF EXISTS sp_get_time_slot_by_id;
DROP PROCEDURE IF EXISTS sp_create_time_slot;
DROP PROCEDURE IF EXISTS sp_update_time_slot;
DROP PROCEDURE IF EXISTS sp_delete_time_slot;
-- Bookings
DROP PROCEDURE IF EXISTS sp_create_booking;
DROP PROCEDURE IF EXISTS sp_update_booking_status;
DROP PROCEDURE IF EXISTS sp_get_booking_history;
DROP PROCEDURE IF EXISTS sp_get_booking_by_id;
DROP PROCEDURE IF EXISTS sp_update_booking_details;
DROP PROCEDURE IF EXISTS sp_cancel_booking;
DROP PROCEDURE IF EXISTS sp_test_connection;

-- Procedure: Admin Login
DELIMITER //
CREATE PROCEDURE sp_admin_login(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255)
)
BEGIN
    DECLARE admin_count INT DEFAULT 0;
    
    SELECT COUNT(*) INTO admin_count
    FROM admins 
    WHERE username = p_username 
      AND password = p_password 
      AND status = 'active';
    
    IF admin_count > 0 THEN
        SELECT admin_id, username, full_name, email, 'success' AS status
        FROM admins 
        WHERE username = p_username AND password = p_password AND status = 'active';
    ELSE
        SELECT 0 AS admin_id, '' AS username, '' AS full_name, '' AS email, 'failed' AS status;
    END IF;
END //
DELIMITER ;

-- ==================== COURT PROCEDURES ====================

-- Get all courts
DELIMITER //
CREATE PROCEDURE sp_get_all_courts()
BEGIN
    SELECT court_id, court_name, description, price_per_session, 
           status, created_at, updated_at 
    FROM courts 
    ORDER BY court_name ASC;
END //
DELIMITER ;

-- Get court by ID
DELIMITER //
CREATE PROCEDURE sp_get_court_by_id(IN p_court_id INT)
BEGIN
    SELECT court_id, court_name, description, price_per_session, 
           status, created_at, updated_at 
    FROM courts 
    WHERE court_id = p_court_id;
END //
DELIMITER ;

-- Create new court
DELIMITER //
CREATE PROCEDURE sp_create_court(
    IN p_court_name VARCHAR(50),
    IN p_description TEXT,
    IN p_price_per_session DECIMAL(10,2),
    IN p_status ENUM('active', 'maintenance', 'inactive')
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    INSERT INTO courts (court_name, description, price_per_session, status) 
    VALUES (p_court_name, p_description, p_price_per_session, COALESCE(p_status, 'active'));
    
    SELECT LAST_INSERT_ID() as court_id, 'success' as status, 'Court created successfully' as message;
    
    COMMIT;
END //
DELIMITER ;

-- Update court
DELIMITER //
CREATE PROCEDURE sp_update_court(
    IN p_court_id INT,
    IN p_court_name VARCHAR(50),
    IN p_description TEXT,
    IN p_price_per_session DECIMAL(10,2),
    IN p_status ENUM('active', 'maintenance', 'inactive')
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    SELECT COUNT(*) INTO v_exists FROM courts WHERE court_id = p_court_id;
    IF v_exists = 0 THEN
        SELECT 'error' as status, 'Court not found' as message;
    ELSE
        UPDATE courts 
        SET 
            court_name = COALESCE(p_court_name, court_name),
            description = COALESCE(p_description, description),
            price_per_session = COALESCE(p_price_per_session, price_per_session),
            status = COALESCE(p_status, status),
            updated_at = CURRENT_TIMESTAMP
        WHERE court_id = p_court_id;
        SELECT 'success' as status, 'Court updated successfully' as message;
    END IF;
    COMMIT;
END //
DELIMITER ;

-- Delete court
DELIMITER //
CREATE PROCEDURE sp_delete_court(IN p_court_id INT)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_booking_count INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    SELECT COUNT(*) INTO v_exists FROM courts WHERE court_id = p_court_id;
    IF v_exists = 0 THEN
        SELECT 'error' as status, 'Court not found' as message;
    ELSE
        SELECT COUNT(*) INTO v_booking_count 
        FROM bookings 
        WHERE court_id = p_court_id AND booking_status != 'cancelled';
        IF v_booking_count > 0 THEN
            SELECT 'error' as status, 'Cannot delete court with active bookings' as message;
        ELSE
            DELETE FROM courts WHERE court_id = p_court_id;
            SELECT 'success' as status, 'Court deleted successfully' as message;
        END IF;
    END IF;
    COMMIT;
END //
DELIMITER ;

-- ==================== TIME SLOT PROCEDURES ====================

-- Get all time slots
DELIMITER //
CREATE PROCEDURE sp_get_all_time_slots()
BEGIN
    SELECT slot_id, start_time, end_time, slot_name, status, created_at 
    FROM time_slots 
    ORDER BY start_time ASC;
END //
DELIMITER ;

-- Get time slot by ID
DELIMITER //
CREATE PROCEDURE sp_get_time_slot_by_id(IN p_slot_id INT)
BEGIN
    SELECT slot_id, start_time, end_time, slot_name, status, created_at 
    FROM time_slots 
    WHERE slot_id = p_slot_id;
END //
DELIMITER ;

-- Create new time slot
DELIMITER //
CREATE PROCEDURE sp_create_time_slot(
    IN p_start_time TIME,
    IN p_end_time TIME,
    IN p_slot_name VARCHAR(50),
    IN p_status ENUM('active', 'inactive')
)
BEGIN
    DECLARE v_overlap_count INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    -- Check for time overlap
    SELECT COUNT(*) INTO v_overlap_count
    FROM time_slots 
    WHERE status = 'active' 
      AND (
          (p_start_time >= start_time AND p_start_time < end_time) OR
          (p_end_time > start_time AND p_end_time <= end_time) OR
          (p_start_time <= start_time AND p_end_time >= end_time)
      );
    
    IF v_overlap_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Time slot overlaps with existing active slot';
    END IF;
    
    IF p_start_time >= p_end_time THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Start time must be before end time';
    END IF;
    
    INSERT INTO time_slots (start_time, end_time, slot_name, status) 
    VALUES (p_start_time, p_end_time, p_slot_name, COALESCE(p_status, 'active'));
    
    SELECT LAST_INSERT_ID() as slot_id, 'success' as status, 'Time slot created successfully' as message;
    
    COMMIT;
END //
DELIMITER ;

-- Update time slot
DELIMITER //
CREATE PROCEDURE sp_update_time_slot(
    IN p_slot_id INT,
    IN p_start_time TIME,
    IN p_end_time TIME,
    IN p_slot_name VARCHAR(50),
    IN p_status ENUM('active', 'inactive')
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_overlap_count INT DEFAULT 0;
    DECLARE v_booking_count INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    SELECT COUNT(*) INTO v_exists FROM time_slots WHERE slot_id = p_slot_id;
    IF v_exists = 0 THEN
        SELECT 'error' as status, 'Time slot not found' as message;
    ELSE
        SELECT COUNT(*) INTO v_booking_count 
        FROM bookings 
        WHERE slot_id = p_slot_id 
          AND booking_status != 'cancelled'
          AND booking_date >= CURDATE();
        IF (p_start_time IS NOT NULL OR p_end_time IS NOT NULL OR p_status = 'inactive') 
           AND v_booking_count > 0 THEN
            SELECT 'error' as status, 'Cannot modify time slot with future active bookings' as message;
        ELSE
            IF p_start_time IS NOT NULL AND p_end_time IS NOT NULL THEN
                IF p_start_time >= p_end_time THEN
                    SELECT 'error' as status, 'Start time must be before end time' as message;
                ELSE
                    SELECT COUNT(*) INTO v_overlap_count
                    FROM time_slots 
                    WHERE slot_id != p_slot_id 
                      AND status = 'active' 
                      AND (
                          (p_start_time >= start_time AND p_start_time < end_time) OR
                          (p_end_time > start_time AND p_end_time <= end_time) OR
                          (p_start_time <= start_time AND p_end_time >= end_time)
                      );
                    IF v_overlap_count > 0 THEN
                        SELECT 'error' as status, 'Time slot overlaps with existing active slot' as message;
                    ELSE
                        UPDATE time_slots 
                        SET 
                            start_time = COALESCE(p_start_time, start_time),
                            end_time = COALESCE(p_end_time, end_time),
                            slot_name = COALESCE(p_slot_name, slot_name),
                            status = COALESCE(p_status, status)
                        WHERE slot_id = p_slot_id;
                        SELECT 'success' as status, 'Time slot updated successfully' as message;
                    END IF;
                END IF;
            ELSE
                UPDATE time_slots 
                SET 
                    slot_name = COALESCE(p_slot_name, slot_name),
                    status = COALESCE(p_status, status)
                WHERE slot_id = p_slot_id;
                SELECT 'success' as status, 'Time slot updated successfully' as message;
            END IF;
        END IF;
    END IF;
    COMMIT;
END //
DELIMITER ;

-- Delete time slot
DELIMITER //
CREATE PROCEDURE sp_delete_time_slot(IN p_slot_id INT)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_booking_count INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    SELECT COUNT(*) INTO v_exists FROM time_slots WHERE slot_id = p_slot_id;
    IF v_exists = 0 THEN
        SELECT 'error' as status, 'Time slot not found' as message;
    ELSE
        SELECT COUNT(*) INTO v_booking_count 
        FROM bookings 
        WHERE slot_id = p_slot_id;
        IF v_booking_count > 0 THEN
            SELECT 'error' as status, 'Cannot delete time slot with existing bookings. Set status to inactive instead.' as message;
        ELSE
            DELETE FROM time_slots WHERE slot_id = p_slot_id;
            SELECT 'success' as status, 'Time slot deleted successfully' as message;
        END IF;
    END IF;
    COMMIT;
END //
DELIMITER ;

-- Get available time slots for court and date
DELIMITER //
CREATE PROCEDURE sp_get_available_time_slots(
    IN p_court_id INT,
    IN p_booking_date DATE
)
BEGIN
    SELECT ts.slot_id, ts.start_time, ts.end_time, ts.slot_name,
           is_slot_available(p_court_id, ts.slot_id, p_booking_date) as is_available
    FROM time_slots ts 
    WHERE ts.status = 'active'
    ORDER BY ts.start_time ASC;
END //
DELIMITER ;

-- ==================== BOOKING PROCEDURES ====================

-- Create New Booking
DELIMITER //
CREATE PROCEDURE sp_create_booking(
    IN p_court_id INT,
    IN p_slot_id INT,
    IN p_booking_date DATE,
    IN p_customer_name VARCHAR(100),
    IN p_customer_phone VARCHAR(20),
    IN p_payment_status ENUM('paid', 'unpaid', 'partial'),
    IN p_notes TEXT,
    IN p_created_by INT
)
BEGIN
    DECLARE v_price DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_booking_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF NOT is_slot_available(p_court_id, p_slot_id, p_booking_date) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Slot sudah dibooking untuk tanggal tersebut';
    END IF;
    SELECT price_per_session INTO v_price
    FROM courts 
    WHERE court_id = p_court_id AND status = 'active';
    IF v_price IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lapangan tidak ditemukan atau tidak aktif';
    END IF;
    INSERT INTO bookings (
        court_id, slot_id, booking_date, customer_name, customer_phone,
        total_amount, payment_status, notes, created_by
    ) VALUES (
        p_court_id, p_slot_id, p_booking_date, p_customer_name, p_customer_phone,
        v_price, p_payment_status, p_notes, p_created_by
    );
    SET v_booking_id = LAST_INSERT_ID();
    COMMIT;
    SELECT v_booking_id AS booking_id, 'success' AS status, 'Booking berhasil dibuat' AS message;
END //
DELIMITER ;

-- Procedure: Update Booking Status
DELIMITER //
CREATE PROCEDURE sp_update_booking_status(
    IN p_booking_id INT,
    IN p_payment_status ENUM('paid', 'unpaid', 'partial'),
    IN p_booking_status ENUM('confirmed', 'cancelled', 'completed'),
    IN p_updated_by INT
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    SELECT COUNT(*) INTO v_exists
    FROM bookings 
    WHERE booking_id = p_booking_id;
    IF v_exists = 0 THEN
        SELECT 'error' AS status, 'Booking tidak ditemukan' AS message;
    ELSE
        UPDATE bookings 
        SET 
            payment_status = COALESCE(p_payment_status, payment_status),
            booking_status = COALESCE(p_booking_status, booking_status),
            updated_at = CURRENT_TIMESTAMP
        WHERE booking_id = p_booking_id;
        SELECT 'success' AS status, 'Status booking berhasil diupdate' AS message;
    END IF;
    COMMIT;
END //
DELIMITER ;

-- Procedure: Get Booking History with Filters
DELIMITER //
CREATE PROCEDURE sp_get_booking_history(
    IN p_court_id INT,
    IN p_start_date DATE,
    IN p_end_date DATE,
    IN p_limit INT,
    IN p_offset INT
)
BEGIN
    DECLARE v_sql TEXT;
    
    SET v_sql = 'SELECT 
                    b.booking_id,
                    c.court_name,
                    ts.slot_name,
                    b.booking_date,
                    b.customer_name,
                    b.customer_phone,
                    b.total_amount,
                    b.payment_status,
                    b.booking_status,
                    b.notes,
                    a.full_name as created_by_name,
                    b.created_at
                 FROM bookings b
                 JOIN courts c ON b.court_id = c.court_id
                 JOIN time_slots ts ON b.slot_id = ts.slot_id
                 JOIN admins a ON b.created_by = a.admin_id
                 WHERE 1=1';
    
    IF p_court_id IS NOT NULL THEN
        SET v_sql = CONCAT(v_sql, ' AND b.court_id = ', p_court_id);
    END IF;
    
    IF p_start_date IS NOT NULL THEN
        SET v_sql = CONCAT(v_sql, ' AND b.booking_date >= ''', p_start_date, '''');
    END IF;
    
    IF p_end_date IS NOT NULL THEN
        SET v_sql = CONCAT(v_sql, ' AND b.booking_date <= ''', p_end_date, '''');
    END IF;
    
    SET v_sql = CONCAT(v_sql, ' ORDER BY b.booking_date DESC, ts.start_time ASC');
    
    IF p_limit IS NOT NULL THEN
        SET v_sql = CONCAT(v_sql, ' LIMIT ', p_limit);
        
        IF p_offset IS NOT NULL THEN
            SET v_sql = CONCAT(v_sql, ' OFFSET ', p_offset);
        END IF;
    END IF;
    
    SET @sql = v_sql;
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END //
DELIMITER ;

-- Get booking by ID
DELIMITER //
CREATE PROCEDURE sp_get_booking_by_id(IN p_booking_id INT)
BEGIN
    SELECT * FROM v_booking_details 
    WHERE booking_id = p_booking_id;
END //
DELIMITER ;

-- Update booking details (information)
DELIMITER //
CREATE PROCEDURE sp_update_booking_details(
    IN p_booking_id INT,
    IN p_customer_name VARCHAR(100),
    IN p_customer_phone VARCHAR(20),
    IN p_notes TEXT
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    SELECT COUNT(*) INTO v_exists FROM bookings WHERE booking_id = p_booking_id;
    IF v_exists = 0 THEN
        SELECT 'error' as status, 'Booking not found' as message;
    ELSE
        UPDATE bookings 
        SET 
            customer_name = COALESCE(p_customer_name, customer_name),
            customer_phone = COALESCE(p_customer_phone, customer_phone),
            notes = COALESCE(p_notes, notes),
            updated_at = CURRENT_TIMESTAMP
        WHERE booking_id = p_booking_id;
        SELECT 'success' as status, 'Booking updated successfully' as message;
    END IF;
    COMMIT;
END //
DELIMITER ;

-- Cancel booking
DELIMITER //
CREATE PROCEDURE sp_cancel_booking(IN p_booking_id INT)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    SELECT COUNT(*) INTO v_exists FROM bookings WHERE booking_id = p_booking_id;
    IF v_exists = 0 THEN
        SELECT 'error' as status, 'Booking not found' as message;
    ELSE
        UPDATE bookings 
        SET booking_status = 'cancelled', updated_at = CURRENT_TIMESTAMP
        WHERE booking_id = p_booking_id;
        SELECT 'success' as status, 'Booking cancelled successfully' as message;
    END IF;
    COMMIT;
END //
DELIMITER ;

-- Test connection
DELIMITER //
CREATE PROCEDURE sp_test_connection()
BEGIN
    DECLARE v_current_time DATETIME;
    DECLARE v_database_name VARCHAR(100);
    DECLARE v_mysql_version VARCHAR(100);
    DECLARE v_total_admins INT DEFAULT 0;
    DECLARE v_total_courts INT DEFAULT 0;
    DECLARE v_total_time_slots INT DEFAULT 0;
    DECLARE v_total_bookings INT DEFAULT 0;
    DECLARE v_active_bookings_today INT DEFAULT 0;
    
    -- Get system info
    SET v_current_time = NOW();
    SELECT DATABASE() INTO v_database_name;
    SELECT VERSION() INTO v_mysql_version;
    
    -- Get table counts
    SELECT COUNT(*) INTO v_total_admins FROM admins;
    SELECT COUNT(*) INTO v_total_courts FROM courts;
    SELECT COUNT(*) INTO v_total_time_slots FROM time_slots;
    SELECT COUNT(*) INTO v_total_bookings FROM bookings;
    SELECT COUNT(*) INTO v_active_bookings_today 
    FROM bookings 
    WHERE booking_date = CURDATE() AND booking_status != 'cancelled';
    
    -- Return connection test result
    SELECT 
        'success' as status,
        'Database connection successful' as message,
        v_current_time as server_time,
        v_database_name as database_name,
        v_mysql_version as mysql_version,
        v_total_admins as total_admins,
        v_total_courts as total_courts,
        v_total_time_slots as total_time_slots,
        v_total_bookings as total_bookings,
        v_active_bookings_today as active_bookings_today,
        CASE 
            WHEN v_total_courts > 0 AND v_total_time_slots > 0 AND v_total_admins > 0 THEN 'ready'
            ELSE 'incomplete_setup'
        END as system_status;
END //
DELIMITER ;

-- =============================================
-- TRIGGERS
-- =============================================

-- Drop existing triggers
DROP TRIGGER IF EXISTS tr_validate_booking_insert;
DROP TRIGGER IF EXISTS tr_booking_status_update;

-- Trigger: Validate booking before insert
DELIMITER //
CREATE TRIGGER tr_validate_booking_insert
    BEFORE INSERT ON bookings
    FOR EACH ROW
BEGIN
    -- Validate booking date (tidak boleh tanggal lampau)
    IF NEW.booking_date < CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tanggal booking tidak boleh tanggal lampau';
    END IF;
    
    -- Validate court status
    IF (SELECT status FROM courts WHERE court_id = NEW.court_id) != 'active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lapangan tidak aktif';
    END IF;
    
    -- Validate time slot status
    IF (SELECT status FROM time_slots WHERE slot_id = NEW.slot_id) != 'active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Slot waktu tidak aktif';
    END IF;
    
    -- Validate customer name
    IF NEW.customer_name IS NULL OR TRIM(NEW.customer_name) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nama customer harus diisi';
    END IF;
    
    -- Set total amount based on court price if not provided
    IF NEW.total_amount = 0.00 THEN
        SET NEW.total_amount = (SELECT price_per_session FROM courts WHERE court_id = NEW.court_id);
    END IF;
END //
DELIMITER ;

-- =============================================
-- VIEWS
-- =============================================

DROP VIEW IF EXISTS v_booking_details;
CREATE VIEW v_booking_details AS
SELECT 
    b.booking_id,
    b.booking_date,
    c.court_name,
    CONCAT(ts.slot_name, ' (', TIME_FORMAT(ts.start_time, '%H:%i'), ' - ', TIME_FORMAT(ts.end_time, '%H:%i'), ')') as time_slot_info,
    b.customer_name,
    b.customer_phone,
    b.total_amount,
    b.payment_status,
    b.booking_status,
    b.notes,
    a.full_name as admin_name,
    b.created_at,
    b.updated_at,
    CASE 
        WHEN b.booking_date < CURDATE() AND b.booking_status = 'confirmed' THEN 'completed'
        ELSE b.booking_status
    END as actual_status
FROM bookings b
JOIN courts c ON b.court_id = c.court_id
JOIN time_slots ts ON b.slot_id = ts.slot_id
JOIN admins a ON b.created_by = a.admin_id
ORDER BY b.booking_date DESC, ts.start_time ASC;


-- =============================================
-- SAMPLE DATA INSERTION
-- =============================================

INSERT INTO admins (username, password, full_name, email) VALUES
('admin', MD5('admin123'), 'Administrator', 'admin@badminton.com'),
('manager', MD5('manager123'), 'Court Manager', 'manager@badminton.com');

-- Insert sample courts
INSERT INTO courts (court_name, description, price_per_session, status) VALUES
('Lapangan 1', 'Lapangan indoor dengan lantai vinyl premium', 50000.00, 'active'),
('Lapangan 2', 'Lapangan indoor standar', 45000.00, 'active'),
('Lapangan 3', 'Lapangan semi-outdoor', 40000.00, 'active');

-- Insert time slots (8 AM to 10 PM, every 2 hours)
INSERT INTO time_slots (start_time, end_time, slot_name, status) VALUES
('08:00:00', '10:00:00', 'Pagi 1 (08:00-10:00)', 'active'),
('10:00:00', '12:00:00', 'Pagi 2 (10:00-12:00)', 'active'),
('12:00:00', '14:00:00', 'Siang 1 (12:00-14:00)', 'active'),
('14:00:00', '16:00:00', 'Siang 2 (14:00-16:00)', 'active'),
('16:00:00', '18:00:00', 'Sore 1 (16:00-18:00)', 'active'),
('18:00:00', '20:00:00', 'Sore 2 (18:00-20:00)', 'active'),
('20:00:00', '22:00:00', 'Malam (20:00-22:00)', 'active');

-- Insert sample bookings
INSERT INTO bookings (court_id, slot_id, booking_date, customer_name, customer_phone, total_amount, payment_status, booking_status, created_by) VALUES
(1, 1, CURDATE(), 'Iqmal Rahman', '081234567890', 50000.00, 'paid', 'confirmed', 1),
(2, 2, CURDATE(), 'Budi Santoso', '081234567891', 45000.00, 'unpaid', 'confirmed', 1),
(1, 3, DATE_ADD(CURDATE(), INTERVAL 1 DAY), 'Siti Nurhaliza', '081234567892', 50000.00, 'paid', 'confirmed', 2),
(3, 1, DATE_ADD(CURDATE(), INTERVAL 1 DAY), 'Agus Wijaya', '081234567893', 40000.00, 'partial', 'confirmed', 1),
(2, 4, DATE_ADD(CURDATE(), INTERVAL 2 DAY), 'Dewi Lestari', '081234567894', 45000.00, 'paid', 'confirmed', 1),
(1, 5, DATE_ADD(CURDATE(), INTERVAL 2 DAY), 'Rudi Hartono', '081234567895', 50000.00, 'unpaid', 'confirmed', 2);

-- =============================================
-- DEMO
-- =============================================

/*
-- 1) LOGIN
CALL sp_admin_login('admin', MD5('admin123'));

-- 2) COURTS
-- Create court demo
CALL sp_create_court('Demo Court A', 'Untuk demo fitur court', 51000.00, 'active');
-- Detail court by id
CALL sp_get_court_by_id(1);
-- Update court demo
CALL sp_update_court(2, 'Lapangan 2 (Update Demo)', 'Update deskripsi demo', 52000.00, 'active');
-- List semua court
CALL sp_get_all_courts();


-- 3) TIME SLOTS
-- Create time slot
CALL sp_create_time_slot('22:00:00', '23:00:00', 'Demo Malam (22-23)', 'active');
-- Tampilkan detail slot by id
CALL sp_get_time_slot_by_id(1);
-- Update slot name
CALL sp_update_time_slot(2, NULL, NULL, 'Pagi 2 (Edit Nama Demo)', 'active');
-- List semua slot
CALL sp_get_all_time_slots();

-- 4) BOOKINGS
-- Create booking demo (court_id=1, slot_id=6)
CALL sp_create_booking(1, 6, DATE_ADD(CURDATE(), INTERVAL 10 DAY), 'Demo Customer', '081230000001', 'paid', 'Booking demo', 1);
-- Tampilkan detail booking via view
CALL sp_get_booking_by_id(1);
-- Update status pembayaran/booking pada ID 1
CALL sp_update_booking_status(1, 'partial', 'confirmed', 1);
-- Update data customer
CALL sp_update_booking_details(2, 'Customer Edit', '081233344455', 'Update catatan booking');
-- Ambil histori booking untuk court 1 dalam 30 hari ke depan (limit 10, offset 0)
CALL sp_get_booking_history(1, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), 10, 0);
-- Batalkan booking
CALL sp_cancel_booking(3);
CALL sp_get_booking_by_id(1);
*/
