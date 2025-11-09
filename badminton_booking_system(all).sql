-- =============================================
-- ADMIN BADMINTON COURT MANAGEMENT SYSTEM
-- Complete SQL Script with Tables, Triggers, 
-- Stored Procedures, Functions, and Views
-- =============================================

-- Drop and Create Database
DROP DATABASE IF EXISTS badminton_court_management;
CREATE DATABASE badminton_court_management;
USE badminton_court_management;

-- =============================================
-- TABLE CREATION (WITH DROP IF EXISTS)
-- =============================================

-- Drop tables if exist (in reverse order due to foreign keys)
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
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_status (status)
);

-- 2. COURTS Table
CREATE TABLE courts (
    court_id INT AUTO_INCREMENT PRIMARY KEY,
    court_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    price_per_session DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status ENUM('active', 'maintenance', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX idx_court_name (court_name),
    INDEX idx_status (status)
);

-- 3. TIME_SLOTS Table
CREATE TABLE time_slots (
    slot_id INT AUTO_INCREMENT PRIMARY KEY,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    slot_name VARCHAR(50) NOT NULL,
    status ENUM('active', 'inactive') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_time_slot (start_time, end_time),
    INDEX idx_start_time (start_time),
    INDEX idx_status (status)
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
    
    UNIQUE KEY unique_booking (court_id, slot_id, booking_date),
    INDEX idx_booking_date (booking_date),
    INDEX idx_court_slot_date (court_id, slot_id, booking_date),
    INDEX idx_payment_status (payment_status),
    INDEX idx_booking_status (booking_status),
    INDEX idx_customer_name (customer_name)
);

-- =============================================
-- FUNCTIONS (WITH DROP IF EXISTS)
-- =============================================

-- Drop existing functions
DROP FUNCTION IF EXISTS is_slot_available;
DROP FUNCTION IF EXISTS get_court_revenue;
DROP FUNCTION IF EXISTS get_available_slots_count;
DROP FUNCTION IF EXISTS get_court_slot_booking_status;

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

-- Function: Calculate total revenue by court
DELIMITER //
CREATE FUNCTION get_court_revenue(
    p_court_id INT,
    p_start_date DATE,
    p_end_date DATE
) RETURNS DECIMAL(10,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE total_revenue DECIMAL(10,2) DEFAULT 0.00;
    
    SELECT COALESCE(SUM(total_amount), 0.00) INTO total_revenue
    FROM bookings 
    WHERE court_id = p_court_id 
      AND booking_date BETWEEN p_start_date AND p_end_date
      AND booking_status != 'cancelled'
      AND payment_status = 'paid';
      
    RETURN total_revenue;
END //
DELIMITER ;

-- Function: Get available slots for specific court and date
DELIMITER //
CREATE FUNCTION get_available_slots_count(
    p_court_id INT,
    p_booking_date DATE
) RETURNS INT
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE total_slots INT DEFAULT 0;
    DECLARE booked_slots INT DEFAULT 0;
    
    SELECT COUNT(*) INTO total_slots FROM time_slots WHERE status = 'active';
    
    SELECT COUNT(*) INTO booked_slots
    FROM bookings 
    WHERE court_id = p_court_id 
      AND booking_date = p_booking_date
      AND booking_status != 'cancelled';
      
    RETURN (total_slots - booked_slots);
END //
DELIMITER ;

-- =============================================
-- STORED PROCEDURES (WITH DROP IF EXISTS)
-- =============================================

-- Drop existing procedures
DROP PROCEDURE IF EXISTS sp_admin_login;
DROP PROCEDURE IF EXISTS sp_create_booking;
DROP PROCEDURE IF EXISTS sp_update_booking_status;
DROP PROCEDURE IF EXISTS sp_get_booking_history;
DROP PROCEDURE IF EXISTS sp_get_dashboard_stats;
DROP PROCEDURE IF EXISTS sp_get_all_courts;
DROP PROCEDURE IF EXISTS sp_get_court_by_id;
DROP PROCEDURE IF EXISTS sp_create_court;
DROP PROCEDURE IF EXISTS sp_update_court;
DROP PROCEDURE IF EXISTS sp_delete_court;
DROP PROCEDURE IF EXISTS sp_get_all_time_slots;
DROP PROCEDURE IF EXISTS sp_get_available_time_slots;
DROP PROCEDURE IF EXISTS sp_get_booking_by_id;
DROP PROCEDURE IF EXISTS sp_update_booking_details;
DROP PROCEDURE IF EXISTS sp_cancel_booking;
DROP PROCEDURE IF EXISTS sp_get_daily_summary;
DROP PROCEDURE IF EXISTS sp_get_revenue_summary;
DROP PROCEDURE IF EXISTS sp_get_court_utilization;
DROP PROCEDURE IF EXISTS sp_create_admin;
DROP PROCEDURE IF EXISTS sp_get_court_slot_booking_status;
DROP PROCEDURE IF EXISTS sp_test_connection;
DROP PROCEDURE IF EXISTS sp_change_admin_password;
DROP PROCEDURE IF EXISTS sp_create_time_slot;
DROP PROCEDURE IF EXISTS sp_update_time_slot;
DROP PROCEDURE IF EXISTS sp_delete_time_slot;
DROP PROCEDURE IF EXISTS sp_get_time_slot_by_id;

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

-- Procedure: Create New Booking
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
    
    -- Check if slot is available
    IF NOT is_slot_available(p_court_id, p_slot_id, p_booking_date) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Slot sudah dibooking untuk tanggal tersebut';
    END IF;
    
    -- Get court price
    SELECT price_per_session INTO v_price
    FROM courts 
    WHERE court_id = p_court_id AND status = 'active';
    
    IF v_price IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lapangan tidak ditemukan atau tidak aktif';
    END IF;
    
    -- Insert booking
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
END //
DELIMITER ;

-- Delete court
DELIMITER //
CREATE PROCEDURE sp_delete_court(IN p_court_id INT)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_booking_count INT DEFAULT 0;
    
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
END //
DELIMITER ;

-- Get all time slots
DELIMITER //
CREATE PROCEDURE sp_get_all_time_slots()
BEGIN
    SELECT slot_id, start_time, end_time, slot_name, status, created_at 
    FROM time_slots 
    ORDER BY start_time ASC;
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

-- Test database connection and system health
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

-- Change admin password
DELIMITER //
CREATE PROCEDURE sp_change_admin_password(
    IN p_admin_id INT,
    IN p_new_password VARCHAR(255)
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    
    SELECT COUNT(*) INTO v_exists FROM admins WHERE admin_id = p_admin_id AND status = 'active';
    
    IF v_exists = 0 THEN
        SELECT 'error' as status, 'Admin not found or inactive' as message;
    ELSE
        UPDATE admins 
        SET password = MD5(p_new_password), updated_at = CURRENT_TIMESTAMP
        WHERE admin_id = p_admin_id;
        
        SELECT 'success' as status, 'Password changed successfully' as message;
    END IF;
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
    
    -- Validate time logic
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
    
    SELECT COUNT(*) INTO v_exists FROM time_slots WHERE slot_id = p_slot_id;
    
    IF v_exists = 0 THEN
        SELECT 'error' as status, 'Time slot not found' as message;
    ELSE
        -- Check if time slot is being used in active bookings
        SELECT COUNT(*) INTO v_booking_count 
        FROM bookings 
        WHERE slot_id = p_slot_id 
          AND booking_status != 'cancelled'
          AND booking_date >= CURDATE();
        
        -- If changing time or status to inactive, check for future bookings
        IF (p_start_time IS NOT NULL OR p_end_time IS NOT NULL OR p_status = 'inactive') 
           AND v_booking_count > 0 THEN
            SELECT 'error' as status, 'Cannot modify time slot with future active bookings' as message;
        ELSE
            -- Check for time overlap if time is being changed
            IF p_start_time IS NOT NULL AND p_end_time IS NOT NULL THEN
                -- Validate time logic
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
                -- Only updating name or status
                UPDATE time_slots 
                SET 
                    slot_name = COALESCE(p_slot_name, slot_name),
                    status = COALESCE(p_status, status)
                WHERE slot_id = p_slot_id;
                
                SELECT 'success' as status, 'Time slot updated successfully' as message;
            END IF;
        END IF;
    END IF;
END //
DELIMITER ;

-- Delete time slot
DELIMITER //
CREATE PROCEDURE sp_delete_time_slot(IN p_slot_id INT)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_booking_count INT DEFAULT 0;
    
    SELECT COUNT(*) INTO v_exists FROM time_slots WHERE slot_id = p_slot_id;
    
    IF v_exists = 0 THEN
        SELECT 'error' as status, 'Time slot not found' as message;
    ELSE
        -- Check if time slot has any bookings (including past ones for history)
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

-- Update booking details (not status)
DELIMITER //
CREATE PROCEDURE sp_update_booking_details(
    IN p_booking_id INT,
    IN p_customer_name VARCHAR(100),
    IN p_customer_phone VARCHAR(20),
    IN p_notes TEXT
)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    
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
END //
DELIMITER ;

-- Cancel booking (soft delete)
DELIMITER //
CREATE PROCEDURE sp_cancel_booking(IN p_booking_id INT)
BEGIN
    DECLARE v_exists INT DEFAULT 0;
    
    SELECT COUNT(*) INTO v_exists FROM bookings WHERE booking_id = p_booking_id;
    
    IF v_exists = 0 THEN
        SELECT 'error' as status, 'Booking not found' as message;
    ELSE
        UPDATE bookings 
        SET booking_status = 'cancelled', updated_at = CURRENT_TIMESTAMP
        WHERE booking_id = p_booking_id;
        
        SELECT 'success' as status, 'Booking cancelled successfully' as message;
    END IF;
END //
DELIMITER ;

-- Get daily booking summary with date range
DELIMITER //
CREATE PROCEDURE sp_get_daily_summary(
    IN p_start_date DATE,
    IN p_end_date DATE
)
BEGIN
    DECLARE v_start_date DATE DEFAULT COALESCE(p_start_date, DATE_SUB(CURDATE(), INTERVAL 7 DAY));
    DECLARE v_end_date DATE DEFAULT COALESCE(p_end_date, CURDATE());
    
    SELECT * FROM v_daily_booking_summary 
    WHERE booking_date BETWEEN v_start_date AND v_end_date
    ORDER BY booking_date DESC, court_name ASC;
END //
DELIMITER ;

-- Get revenue summary
DELIMITER //
CREATE PROCEDURE sp_get_revenue_summary(
    IN p_year VARCHAR(4),
    IN p_court_id INT
)
BEGIN
    DECLARE v_year VARCHAR(4) DEFAULT COALESCE(p_year, YEAR(CURDATE()));
    
    IF p_court_id IS NULL THEN
        SELECT * FROM v_revenue_summary 
        WHERE month_year LIKE CONCAT(v_year, '%')
        ORDER BY month_year DESC, court_name ASC;
    ELSE
        SELECT * FROM v_revenue_summary 
        WHERE month_year LIKE CONCAT(v_year, '%')
          AND court_name = (SELECT court_name FROM courts WHERE court_id = p_court_id)
        ORDER BY month_year DESC, court_name ASC;
    END IF;
END //
DELIMITER ;

-- Get court utilization
DELIMITER //
CREATE PROCEDURE sp_get_court_utilization()
BEGIN
    SELECT * FROM v_court_utilization;
END //
DELIMITER ;

-- Create admin (for registration/management)
DELIMITER //
CREATE PROCEDURE sp_create_admin(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_full_name VARCHAR(100),
    IN p_email VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    INSERT INTO admins (username, password, full_name, email) 
    VALUES (p_username, MD5(p_password), p_full_name, p_email);
    
    SELECT LAST_INSERT_ID() as admin_id, 'success' as status, 'Admin created successfully' as message;
    
    COMMIT;
END //
DELIMITER ;

-- Get court slot booking status (alternative to function - returns table format)
DELIMITER //
CREATE PROCEDURE sp_get_court_slot_booking_status(
    IN p_court_id INT,
    IN p_booking_date DATE
)
BEGIN
    DECLARE v_court_name VARCHAR(50);
    DECLARE v_total_slots INT DEFAULT 0;
    DECLARE v_booked_slots INT DEFAULT 0;
    
    -- Get court name
    SELECT court_name INTO v_court_name FROM courts WHERE court_id = p_court_id;
    
    -- Get total and booked slots count
    SELECT COUNT(*) INTO v_total_slots FROM time_slots WHERE status = 'active';
    SELECT COUNT(*) INTO v_booked_slots 
    FROM bookings 
    WHERE court_id = p_court_id 
      AND booking_date = p_booking_date 
      AND booking_status != 'cancelled';
    
    -- Return slot details with booking info
    SELECT 
        p_court_id as court_id,
        v_court_name as court_name,
        p_booking_date as booking_date,
        v_total_slots as total_slots,
        v_booked_slots as booked_slots,
        (v_total_slots - v_booked_slots) as available_slots,
        ts.slot_id,
        ts.slot_name,
        TIME_FORMAT(ts.start_time, '%H:%i') as start_time,
        TIME_FORMAT(ts.end_time, '%H:%i') as end_time,
        CASE WHEN b.booking_id IS NOT NULL THEN 1 ELSE 0 END as is_booked,
        b.booking_id,
        b.customer_name,
        b.customer_phone,
        b.payment_status,
        b.booking_status,
        b.total_amount,
        b.notes,
        a.full_name as created_by_name
    FROM time_slots ts
    LEFT JOIN bookings b ON (
        b.court_id = p_court_id 
        AND b.slot_id = ts.slot_id 
        AND b.booking_date = p_booking_date 
        AND b.booking_status != 'cancelled'
    )
    LEFT JOIN admins a ON b.created_by = a.admin_id
    WHERE ts.status = 'active'
    ORDER BY ts.start_time ASC;
END //
DELIMITER ;

-- Procedure: Get Dashboard Statistics
DELIMITER //
CREATE PROCEDURE sp_get_dashboard_stats(
    IN p_date DATE
)
BEGIN
    DECLARE v_target_date DATE DEFAULT COALESCE(p_date, CURDATE());
    
    SELECT 
        (SELECT COUNT(*) FROM courts WHERE status = 'active') as total_courts,
        (SELECT COUNT(*) FROM bookings WHERE booking_date = v_target_date AND booking_status != 'cancelled') as today_bookings,
        (SELECT COUNT(*) FROM bookings WHERE booking_date = v_target_date AND payment_status = 'paid' AND booking_status != 'cancelled') as paid_bookings,
        (SELECT COUNT(*) FROM bookings WHERE booking_date = v_target_date AND payment_status = 'unpaid' AND booking_status != 'cancelled') as unpaid_bookings,
        (SELECT COALESCE(SUM(total_amount), 0) FROM bookings WHERE booking_date = v_target_date AND payment_status = 'paid' AND booking_status != 'cancelled') as daily_revenue,
        (SELECT COALESCE(SUM(total_amount), 0) FROM bookings WHERE MONTH(booking_date) = MONTH(v_target_date) AND YEAR(booking_date) = YEAR(v_target_date) AND payment_status = 'paid' AND booking_status != 'cancelled') as monthly_revenue;
END //
DELIMITER ;

-- =============================================
-- TRIGGERS (WITH DROP IF EXISTS)
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

-- Trigger: Log booking updates
DELIMITER //
CREATE TRIGGER tr_booking_status_update
    AFTER UPDATE ON bookings
    FOR EACH ROW
BEGIN
    -- You can add logging logic here if needed
    -- For now, we just ensure updated_at is properly set
    -- (already handled by ON UPDATE CURRENT_TIMESTAMP in table definition)
    
    -- Validate status transitions
    IF OLD.booking_status = 'cancelled' AND NEW.booking_status != 'cancelled' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking yang sudah dibatalkan tidak bisa diubah statusnya';
    END IF;
END //
DELIMITER ;

-- =============================================
-- VIEWS (WITH DROP IF EXISTS)
-- =============================================

-- Drop existing views
DROP VIEW IF EXISTS v_daily_booking_summary;
DROP VIEW IF EXISTS v_court_utilization;
DROP VIEW IF EXISTS v_booking_details;
DROP VIEW IF EXISTS v_revenue_summary;

-- View: Daily Booking Summary
CREATE VIEW v_daily_booking_summary AS
SELECT 
    b.booking_date,
    c.court_name,
    COUNT(*) as total_bookings,
    SUM(CASE WHEN b.payment_status = 'paid' THEN 1 ELSE 0 END) as paid_bookings,
    SUM(CASE WHEN b.payment_status = 'unpaid' THEN 1 ELSE 0 END) as unpaid_bookings,
    SUM(CASE WHEN b.booking_status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_bookings,
    SUM(CASE WHEN b.payment_status = 'paid' AND b.booking_status != 'cancelled' THEN b.total_amount ELSE 0 END) as daily_revenue
FROM bookings b
JOIN courts c ON b.court_id = c.court_id
GROUP BY b.booking_date, b.court_id, c.court_name
ORDER BY b.booking_date DESC, c.court_name;

-- View: Court Utilization
CREATE VIEW v_court_utilization AS
SELECT 
    c.court_id,
    c.court_name,
    c.status as court_status,
    COUNT(CASE WHEN b.booking_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) AND b.booking_status != 'cancelled' THEN 1 END) as bookings_last_30_days,
    COUNT(CASE WHEN b.booking_date = CURDATE() AND b.booking_status != 'cancelled' THEN 1 END) as today_bookings,
    (SELECT COUNT(*) FROM time_slots WHERE status = 'active') as total_available_slots,
    get_available_slots_count(c.court_id, CURDATE()) as available_slots_today,
    get_court_revenue(c.court_id, DATE_SUB(CURDATE(), INTERVAL 30 DAY), CURDATE()) as revenue_last_30_days
FROM courts c
LEFT JOIN bookings b ON c.court_id = b.court_id
GROUP BY c.court_id, c.court_name, c.status
ORDER BY c.court_name;

-- View: Booking Details (for reports)
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

-- View: Revenue Summary
CREATE VIEW v_revenue_summary AS
SELECT 
    DATE_FORMAT(b.booking_date, '%Y-%m') as month_year,
    c.court_name,
    COUNT(CASE WHEN b.booking_status != 'cancelled' THEN 1 END) as total_bookings,
    SUM(CASE WHEN b.payment_status = 'paid' AND b.booking_status != 'cancelled' THEN b.total_amount ELSE 0 END) as paid_revenue,
    SUM(CASE WHEN b.payment_status = 'unpaid' AND b.booking_status != 'cancelled' THEN b.total_amount ELSE 0 END) as outstanding_revenue,
    SUM(CASE WHEN b.payment_status = 'partial' AND b.booking_status != 'cancelled' THEN b.total_amount ELSE 0 END) as partial_revenue
FROM bookings b
JOIN courts c ON b.court_id = c.court_id
GROUP BY DATE_FORMAT(b.booking_date, '%Y-%m'), b.court_id, c.court_name
ORDER BY month_year DESC, c.court_name;

-- =============================================
-- SAMPLE DATA INSERTION
-- =============================================

-- Insert sample admins (password: admin123 dan manager123)
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
-- USEFUL QUERIES FOR API
-- =============================================

/*
-- Login Admin
CALL sp_admin_login('admin', MD5('admin123'));

-- Create New Booking
CALL sp_create_booking(1, 4, '2024-12-25', 'John Doe', '081234567890', 'paid', 'Booking untuk acara keluarga', 1);

-- Get Booking History (All)
CALL sp_get_booking_history(NULL, NULL, NULL, 50, 0);

-- Get Booking History (Specific Court)
CALL sp_get_booking_history(1, NULL, NULL, 50, 0);

-- Get Booking History (Date Range)
CALL sp_get_booking_history(NULL, '2024-12-01', '2024-12-31', 50, 0);

-- Update Booking Status
CALL sp_update_booking_status(1, 'paid', 'completed', 1);

-- Get Dashboard Statistics
CALL sp_get_dashboard_stats(CURDATE());

-- Check Slot Availability
SELECT is_slot_available(1, 2, '2024-12-25') as is_available;

-- Get Court Revenue
SELECT get_court_revenue(1, '2024-12-01', '2024-12-31') as revenue;

-- Get Available Slots Count
SELECT get_available_slots_count(1, CURDATE()) as available_slots;

-- Get Court Slot Booking Status (STORED PROCEDURE VERSION)
CALL sp_get_court_slot_booking_status(1, CURDATE());

-- Test Database Connection
CALL sp_test_connection();

-- View Reports
SELECT * FROM v_daily_booking_summary WHERE booking_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY);
SELECT * FROM v_court_utilization;
SELECT * FROM v_booking_details WHERE booking_date = CURDATE();
SELECT * FROM v_revenue_summary WHERE month_year = DATE_FORMAT(CURDATE(), '%Y-%m');
*/