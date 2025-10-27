-- ============================================
-- PROFESSIONAL GAMESTORE DATABASE
-- Includes: DDL, DML, Views, Procedures, Functions, Triggers
-- ============================================

DROP DATABASE IF EXISTS gamestore_db;
CREATE DATABASE gamestore_db;
USE gamestore_db;

-- ============================================
-- DDL - TABLE DEFINITIONS
-- ============================================

-- USERS table
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100),
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_spent DECIMAL(10, 2) DEFAULT 0,
    account_status ENUM('active', 'suspended', 'deleted') DEFAULT 'active',
    last_login TIMESTAMP NULL,
    country VARCHAR(50) DEFAULT 'India'
);

-- PUBLISHERS table
CREATE TABLE publishers (
    publisher_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(100),
    password VARCHAR(255) NOT NULL,
    description TEXT,
    total_revenue DECIMAL(10, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    website VARCHAR(255),
    verified BOOLEAN DEFAULT FALSE
);

-- CATEGORIES table
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(50),
    display_order INT DEFAULT 0
);

-- GAMES table (enhanced)
CREATE TABLE games (
    game_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    genre VARCHAR(50) NOT NULL,
    category_id INT,
    price DECIMAL(10, 2) NOT NULL,
    discount_percent INT DEFAULT 0,
    publisher_id INT NOT NULL,
    release_date DATE,
    total_sales INT DEFAULT 0,
    average_rating DECIMAL(3, 2) DEFAULT 0,
    image_url VARCHAR(255),
    is_featured BOOLEAN DEFAULT FALSE,
    is_free BOOLEAN DEFAULT FALSE,
    age_rating VARCHAR(10) DEFAULT 'E',
    file_size VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (publisher_id) REFERENCES publishers(publisher_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(category_id),
    INDEX idx_genre (genre),
    INDEX idx_price (price),
    INDEX idx_rating (average_rating)
);

-- REVIEWS table
CREATE TABLE reviews (
    review_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    game_id INT NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    helpful_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_game (user_id, game_id)
);

-- WISHLIST table
CREATE TABLE wishlist (
    wishlist_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    game_id INT NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    UNIQUE KEY unique_wishlist (user_id, game_id)
);

-- CART table
CREATE TABLE cart (
    cart_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    game_id INT NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
);

-- PURCHASES table
CREATE TABLE purchases (
    purchase_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    game_id INT NOT NULL,
    price_paid DECIMAL(10, 2) NOT NULL,
    purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    payment_method VARCHAR(50),
    transaction_id VARCHAR(100),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE
);

-- GAME ANALYTICS table (new for publisher insights)
CREATE TABLE game_analytics (
    analytics_id INT AUTO_INCREMENT PRIMARY KEY,
    game_id INT NOT NULL,
    date DATE NOT NULL,
    views INT DEFAULT 0,
    wishlist_adds INT DEFAULT 0,
    cart_adds INT DEFAULT 0,
    purchases INT DEFAULT 0,
    revenue DECIMAL(10, 2) DEFAULT 0,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    UNIQUE KEY unique_game_date (game_id, date)
);
-- ============================================
-- FUNCTIONS
-- ============================================
DELIMITER //

-- Function 1: Calculate Final Price
CREATE FUNCTION fn_calculate_price(p_price DECIMAL(10,2), p_discount INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    RETURN ROUND(p_price * (1 - p_discount / 100), 2);
END //

-- Function 2: Get User Tier (based on spending)
CREATE FUNCTION fn_get_user_tier(p_user_id INT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE total DECIMAL(10,2);
    DECLARE tier VARCHAR(20);
    
    SELECT total_spent INTO total FROM users WHERE user_id = p_user_id;
    
    IF total >= 10000 THEN
        SET tier = 'Platinum';
    ELSEIF total >= 5000 THEN
        SET tier = 'Gold';
    ELSEIF total >= 1000 THEN
        SET tier = 'Silver';
    ELSE
        SET tier = 'Bronze';
    END IF;
    
    RETURN tier;
END //

-- Function 3: Calculate Publisher Rating
CREATE FUNCTION fn_publisher_rating(p_publisher_id INT)
RETURNS DECIMAL(3,2)
DETERMINISTIC
BEGIN
    DECLARE avg_rating DECIMAL(3,2);
    
    SELECT AVG(average_rating) INTO avg_rating
    FROM games
    WHERE publisher_id = p_publisher_id;
    
    RETURN COALESCE(avg_rating, 0);
END //

-- Function 4: Check if Game is Trending
CREATE FUNCTION fn_is_trending(p_game_id INT)
RETURNS BOOLEAN
DETERMINISTIC
BEGIN
    DECLARE recent_sales INT;
    
    SELECT COUNT(*) INTO recent_sales
    FROM purchases
    WHERE game_id = p_game_id
    AND purchase_date >= DATE_SUB(NOW(), INTERVAL 7 DAY);
    
    RETURN recent_sales >= 10;
END //

-- ============================================
-- VIEWS - Role-Based Dashboards
-- ============================================

-- ===========================================
-- USER-FACING VIEWS (What users see)
-- ===========================================

-- View 1: User's Complete Dashboard View
CREATE VIEW view_user_dashboard AS
SELECT 
    u.user_id,
    u.username,
    u.total_spent,
    u.created_at as member_since,
    COUNT(DISTINCT p.purchase_id) as total_games_owned,
    COUNT(DISTINCT w.wishlist_id) as wishlist_count,
    COUNT(DISTINCT c.cart_id) as cart_count,
    COUNT(DISTINCT r.review_id) as reviews_written,
    (SELECT fn_get_user_tier(u.user_id)) as membership_tier
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id
LEFT JOIN wishlist w ON u.user_id = w.user_id
LEFT JOIN cart c ON u.user_id = c.user_id
LEFT JOIN reviews r ON u.user_id = r.user_id
GROUP BY u.user_id, u.username, u.total_spent, u.created_at;

-- View 2: User's Library View (All owned games)
CREATE VIEW view_user_library AS
SELECT 
    p.user_id,
    p.purchase_id,
    g.game_id,
    g.title,
    g.genre,
    pub.name as publisher_name,
    g.average_rating,
    p.purchase_date,
    p.price_paid,
    DATEDIFF(CURRENT_DATE, p.purchase_date) as days_owned,
    CASE 
        WHEN EXISTS (SELECT 1 FROM reviews r WHERE r.user_id = p.user_id AND r.game_id = g.game_id)
        THEN 'Reviewed'
        ELSE 'Not Reviewed'
    END as review_status
FROM purchases p
JOIN games g ON p.game_id = g.game_id
JOIN publishers pub ON g.publisher_id = pub.publisher_id
ORDER BY p.purchase_date DESC;

-- View 3: User's Active Cart View
CREATE VIEW view_user_cart AS
SELECT 
    c.cart_id,
    c.user_id,
    g.game_id,
    g.title,
    g.genre,
    pub.name as publisher_name,
    g.price as original_price,
    g.discount_percent,
    ROUND(g.price * (1 - g.discount_percent / 100), 2) as final_price,
    ROUND(g.price * g.discount_percent / 100, 2) as savings,
    c.added_at,
    DATEDIFF(CURRENT_DATE, c.added_at) as days_in_cart
FROM cart c
JOIN games g ON c.game_id = g.game_id
JOIN publishers pub ON g.publisher_id = pub.publisher_id
ORDER BY c.added_at DESC;

-- View 4: User's Wishlist View
CREATE VIEW view_user_wishlist AS
SELECT 
    w.wishlist_id,
    w.user_id,
    g.game_id,
    g.title,
    g.genre,
    pub.name as publisher_name,
    g.price,
    g.discount_percent,
    ROUND(g.price * (1 - g.discount_percent / 100), 2) as current_price,
    w.added_at,
    g.average_rating,
    g.total_sales,
    CASE 
        WHEN g.discount_percent > 0 THEN 'On Sale'
        ELSE 'Regular Price'
    END as sale_status
FROM wishlist w
JOIN games g ON w.game_id = g.game_id
JOIN publishers pub ON g.publisher_id = pub.publisher_id
ORDER BY w.added_at DESC;

-- View 5: User's Purchase History with Stats
CREATE VIEW view_user_purchase_history AS
SELECT 
    p.user_id,
    p.purchase_id,
    g.title,
    g.genre,
    p.price_paid,
    p.purchase_date,
    p.payment_method,
    p.transaction_id,
    MONTH(p.purchase_date) as purchase_month,
    YEAR(p.purchase_date) as purchase_year
FROM purchases p
JOIN games g ON p.game_id = g.game_id
ORDER BY p.purchase_date DESC;

-- View 6: Personalized Game Recommendations for Users
CREATE VIEW view_user_recommendations AS
SELECT DISTINCT
    g.game_id,
    g.title,
    g.genre,
    g.category_id,
    pub.name as publisher_name,
    g.average_rating,
    g.total_sales,
    ROUND(g.price * (1 - g.discount_percent / 100), 2) as final_price,
    g.discount_percent,
    g.is_featured,
    'Based on your library' as recommendation_reason
FROM games g
JOIN publishers pub ON g.publisher_id = pub.publisher_id
WHERE g.average_rating >= 4.0
AND g.game_id NOT IN (SELECT game_id FROM purchases)
ORDER BY g.total_sales DESC, g.average_rating DESC;

-- ===========================================
-- PUBLISHER-FACING VIEWS (What publishers see)
-- ===========================================

-- View 7: Publisher's Complete Dashboard
CREATE VIEW view_publisher_dashboard AS
SELECT 
    p.publisher_id,
    p.name as publisher_name,
    p.total_revenue,
    p.verified,
    COUNT(DISTINCT g.game_id) as total_games_published,
    SUM(g.total_sales) as total_units_sold,
    ROUND(AVG(g.average_rating), 2) as average_game_rating,
    COUNT(DISTINCT CASE WHEN g.is_featured THEN g.game_id END) as featured_games,
    COUNT(DISTINCT CASE WHEN g.discount_percent > 0 THEN g.game_id END) as games_on_sale,
    COUNT(DISTINCT CASE WHEN g.is_free THEN g.game_id END) as free_games,
    (SELECT COUNT(*) FROM games WHERE publisher_id = p.publisher_id AND average_rating >= 4.0) as highly_rated_games,
    (SELECT COUNT(*) FROM games WHERE publisher_id = p.publisher_id AND total_sales > 1000) as bestseller_games
FROM publishers p
LEFT JOIN games g ON p.publisher_id = g.publisher_id
GROUP BY p.publisher_id, p.name, p.total_revenue, p.verified;

-- View 8: Publisher's Game Portfolio View
CREATE VIEW view_publisher_games AS
SELECT 
    g.game_id,
    g.publisher_id,
    g.title,
    g.genre,
    c.name as category,
    g.price,
    g.discount_percent,
    ROUND(g.price * (1 - g.discount_percent / 100), 2) as current_price,
    g.total_sales,
    ROUND(g.price * g.total_sales * (1 - g.discount_percent / 100), 2) as total_revenue,
    g.average_rating,
    (SELECT COUNT(*) FROM reviews WHERE game_id = g.game_id) as review_count,
    (SELECT COUNT(*) FROM wishlist WHERE game_id = g.game_id) as wishlist_count,
    g.release_date,
    g.is_featured,
    g.is_free,
    DATEDIFF(CURRENT_DATE, g.release_date) as days_since_release,
    CASE 
        WHEN g.total_sales >= 10000 THEN 'Blockbuster'
        WHEN g.total_sales >= 5000 THEN 'Hit'
        WHEN g.total_sales >= 1000 THEN 'Popular'
        WHEN g.total_sales >= 100 THEN 'Moderate'
        ELSE 'New'
    END as performance_tier
FROM games g
LEFT JOIN categories c ON g.category_id = c.category_id
ORDER BY g.total_sales DESC;

-- View 9: Publisher's Sales Analytics (Monthly Breakdown)
CREATE VIEW view_publisher_sales_analytics AS
SELECT 
    pub.publisher_id,
    pub.name as publisher_name,
    g.game_id,
    g.title,
    DATE_FORMAT(p.purchase_date, '%Y-%m') as month,
    COUNT(*) as monthly_sales,
    SUM(p.price_paid) as monthly_revenue,
    ROUND(AVG(p.price_paid), 2) as avg_sale_price
FROM purchases p
JOIN games g ON p.game_id = g.game_id
JOIN publishers pub ON g.publisher_id = pub.publisher_id
GROUP BY pub.publisher_id, pub.name, g.game_id, g.title, DATE_FORMAT(p.purchase_date, '%Y-%m')
ORDER BY pub.publisher_id, month DESC, monthly_revenue DESC;

-- View 10: Publisher's Top Performing Games
CREATE VIEW view_publisher_top_games AS
SELECT 
    g.publisher_id,
    g.game_id,
    g.title,
    g.total_sales,
    ROUND(g.price * g.total_sales * (1 - g.discount_percent / 100), 2) as revenue,
    g.average_rating,
    (SELECT COUNT(*) FROM reviews WHERE game_id = g.game_id) as reviews,
    (SELECT COUNT(*) FROM wishlist WHERE game_id = g.game_id) as wishlisted,
    RANK() OVER (PARTITION BY g.publisher_id ORDER BY g.total_sales DESC) as sales_rank,
    RANK() OVER (PARTITION BY g.publisher_id ORDER BY g.average_rating DESC) as rating_rank
FROM games g
WHERE g.total_sales > 0
ORDER BY g.publisher_id, g.total_sales DESC;

-- View 11: Publisher's Revenue by Category
CREATE VIEW view_publisher_category_revenue AS
SELECT 
    pub.publisher_id,
    pub.name as publisher_name,
    c.name as category,
    COUNT(g.game_id) as games_in_category,
    SUM(g.total_sales) as total_sales,
    ROUND(SUM(g.price * g.total_sales * (1 - g.discount_percent / 100)), 2) as category_revenue,
    ROUND(AVG(g.average_rating), 2) as avg_rating_in_category
FROM publishers pub
JOIN games g ON pub.publisher_id = g.publisher_id
JOIN categories c ON g.category_id = c.category_id
GROUP BY pub.publisher_id, pub.name, c.name
ORDER BY pub.publisher_id, category_revenue DESC;

-- View 12: Publisher's Customer Reviews Summary
CREATE VIEW view_publisher_reviews AS
SELECT 
    pub.publisher_id,
    pub.name as publisher_name,
    g.game_id,
    g.title,
    r.review_id,
    u.username,
    r.rating,
    r.review_text,
    r.created_at,
    r.helpful_count
FROM publishers pub
JOIN games g ON pub.publisher_id = g.publisher_id
JOIN reviews r ON g.game_id = r.game_id
JOIN users u ON r.user_id = u.user_id
ORDER BY pub.publisher_id, r.created_at DESC;

-- ===========================================
-- SHARED/PUBLIC VIEWS (Both can see)
-- ===========================================

-- View 13: Trending Games (Hot Right Now)
CREATE VIEW view_trending_games AS
SELECT 
    g.game_id,
    g.title,
    pub.name as publisher_name,
    g.genre,
    ROUND(g.price * (1 - g.discount_percent / 100), 2) as current_price,
    g.average_rating,
    g.total_sales,
    (SELECT COUNT(*) FROM purchases WHERE game_id = g.game_id AND purchase_date >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)) as recent_sales,
    (SELECT COUNT(*) FROM wishlist WHERE game_id = g.game_id) as wishlist_count,
    fn_is_trending(g.game_id) as is_trending
FROM games g
JOIN publishers pub ON g.publisher_id = pub.publisher_id
WHERE (SELECT COUNT(*) FROM purchases WHERE game_id = g.game_id AND purchase_date >= DATE_SUB(CURRENT_DATE, INTERVAL 7 DAY)) > 0
ORDER BY recent_sales DESC, g.average_rating DESC
LIMIT 20;

-- View 14: Best Value Games (High Rating + Low Price)
CREATE VIEW view_best_value_games AS
SELECT 
    g.game_id,
    g.title,
    pub.name as publisher_name,
    g.price,
    g.discount_percent,
    ROUND(g.price * (1 - g.discount_percent / 100), 2) as final_price,
    g.average_rating,
    g.total_sales,
    ROUND((g.average_rating / NULLIF(g.price * (1 - g.discount_percent / 100), 0)) * 10, 2) as value_score
FROM games g
JOIN publishers pub ON g.publisher_id = pub.publisher_id
WHERE g.average_rating >= 4.0
AND g.price > 0
ORDER BY value_score DESC
LIMIT 20;

-- ============================================
-- STORED PROCEDURES
-- ============================================

DELIMITER //

-- Procedure 1: Get Game Details with Stats
CREATE PROCEDURE sp_get_game_details(IN p_game_id INT)
BEGIN
    SELECT 
        g.*,
        p.name as publisher_name,
        p.website as publisher_website,
        c.name as category_name,
        ROUND(g.price * (1 - g.discount_percent / 100), 2) as final_price,
        COUNT(DISTINCT r.review_id) as review_count,
        COUNT(DISTINCT w.wishlist_id) as wishlist_count
    FROM games g
    JOIN publishers p ON g.publisher_id = p.publisher_id
    LEFT JOIN categories c ON g.category_id = c.category_id
    LEFT JOIN reviews r ON g.game_id = r.game_id
    LEFT JOIN wishlist w ON g.game_id = w.game_id
    WHERE g.game_id = p_game_id
    GROUP BY g.game_id;
END //

-- Procedure 2: Get Publisher Analytics
CREATE PROCEDURE sp_publisher_analytics(IN p_publisher_id INT)
BEGIN
    -- Monthly revenue
    SELECT 
        DATE_FORMAT(purchase_date, '%Y-%m') as month,
        COUNT(*) as sales,
        SUM(price_paid) as revenue
    FROM purchases pur
    JOIN games g ON pur.game_id = g.game_id
    WHERE g.publisher_id = p_publisher_id
    GROUP BY DATE_FORMAT(purchase_date, '%Y-%m')
    ORDER BY month DESC
    LIMIT 12;
    
    -- Top games
    SELECT 
        g.game_id, g.title, g.total_sales, g.average_rating,
        ROUND(g.price * g.total_sales * (1 - g.discount_percent / 100), 2) as revenue
    FROM games g
    WHERE g.publisher_id = p_publisher_id
    ORDER BY g.total_sales DESC
    LIMIT 10;
    
    -- Category breakdown
    SELECT 
        c.name as category,
        COUNT(g.game_id) as game_count,
        SUM(g.total_sales) as total_sales
    FROM games g
    JOIN categories c ON g.category_id = c.category_id
    WHERE g.publisher_id = p_publisher_id
    GROUP BY c.name;
END //

-- Procedure 3: User Recommendations (based on owned games)
CREATE PROCEDURE sp_get_recommendations(IN p_user_id INT)
BEGIN
    -- Games similar to what user owns
    SELECT DISTINCT g.game_id, g.title, g.genre, g.average_rating,
           ROUND(g.price * (1 - g.discount_percent / 100), 2) as final_price,
           p.name as publisher_name
    FROM games g
    JOIN publishers p ON g.publisher_id = p.publisher_id
    WHERE g.genre IN (
        SELECT DISTINCT g2.genre 
        FROM purchases pur
        JOIN games g2 ON pur.game_id = g2.game_id
        WHERE pur.user_id = p_user_id
    )
    AND g.game_id NOT IN (
        SELECT game_id FROM purchases WHERE user_id = p_user_id
    )
    ORDER BY g.average_rating DESC, g.total_sales DESC
    LIMIT 10;
END //

-- Procedure 4: Apply Discount to Games
CREATE PROCEDURE sp_apply_discount(
    IN p_publisher_id INT,
    IN p_discount_percent INT,
    IN p_category_id INT
)
BEGIN
    UPDATE games
    SET discount_percent = p_discount_percent
    WHERE publisher_id = p_publisher_id
    AND (p_category_id IS NULL OR category_id = p_category_id);
    
    SELECT ROW_COUNT() as games_updated;
END //


-- ============================================
-- TRIGGERS
-- ============================================

-- Trigger 1: Update game ratings
CREATE TRIGGER tr_update_rating_after_review
AFTER INSERT ON reviews
FOR EACH ROW
BEGIN
    UPDATE games 
    SET average_rating = (
        SELECT AVG(rating) 
        FROM reviews 
        WHERE game_id = NEW.game_id
    )
    WHERE game_id = NEW.game_id;
END //

-- Trigger 2: Update sales and revenue
CREATE TRIGGER tr_update_sales_after_purchase
AFTER INSERT ON purchases
FOR EACH ROW
BEGIN
    -- Update game sales
    UPDATE games 
    SET total_sales = total_sales + 1
    WHERE game_id = NEW.game_id;
    
    -- Update publisher revenue
    UPDATE publishers
    SET total_revenue = total_revenue + NEW.price_paid
    WHERE publisher_id = (SELECT publisher_id FROM games WHERE game_id = NEW.game_id);
    
    -- Update user spending
    UPDATE users
    SET total_spent = total_spent + NEW.price_paid
    WHERE user_id = NEW.user_id;
END //

-- Trigger 3: Track analytics on purchase
CREATE TRIGGER tr_track_analytics_purchase
AFTER INSERT ON purchases
FOR EACH ROW
BEGIN
    INSERT INTO game_analytics (game_id, date, purchases, revenue)
    VALUES (NEW.game_id, CURDATE(), 1, NEW.price_paid)
    ON DUPLICATE KEY UPDATE 
        purchases = purchases + 1,
        revenue = revenue + NEW.price_paid;
END //

-- Trigger 4: Prevent negative prices
CREATE TRIGGER tr_validate_game_price
BEFORE INSERT ON games
FOR EACH ROW
BEGIN
    IF NEW.price < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Price cannot be negative';
    END IF;
    
    IF NEW.discount_percent < 0 OR NEW.discount_percent > 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Discount must be between 0 and 100';
    END IF;
END //

DELIMITER ;

-- ============================================
-- DML - SAMPLE DATA
-- ============================================

-- Insert Categories
INSERT INTO categories (name, description, icon, display_order) VALUES 
('Action', 'Fast-paced games with combat', '⚔️', 1),
('Sports', 'Competitive sports games', '⚽', 2),
('RPG', 'Role-playing adventures', '🎭', 3),
('Strategy', 'Tactical gameplay', '♟️', 4),
('Adventure', 'Story-driven exploration', '🗺️', 5),
('Shooter', 'First/third-person shooting', '🎯', 6),
('Simulation', 'Life and vehicle sims', '🚗', 7),
('Horror', 'Scary and suspenseful', '👻', 8);

-- Insert Users
INSERT INTO users (username, email, password, country) VALUES 
('swayam', 'swayam@gamestore.com', 'pass123', 'India'),
('aditya', 'aditya@gamestore.com', 'pass123', 'India'),
('krish', 'krish@gamestore.com', 'pass123', 'India'),
('saniya', 'saniya@gamestore.com', 'pass123', 'India');
truncate publishers;
-- Insert Publishers
INSERT INTO publishers (name, email, password, description, website, verified) VALUES 
('ea_games', 'contact@ea.com', 'pass123', 'Leading sports and action publisher', 'https://ea.com', TRUE),
('Rockstar Games', 'info@rockstar.com', 'pass123', 'Creators of open-world masterpieces', 'https://rockstargames.com', TRUE),
('Nintendo', 'support@nintendo.com', 'pass123', 'Family-friendly gaming pioneers', 'https://nintendo.com', TRUE),
('Valve', 'hello@valve.com', 'pass123', 'Innovative PC gaming company', 'https://valvesoftware.com', TRUE),
('Ubisoft', 'contact@ubisoft.com', 'pass123', 'Action-adventure specialists', 'https://ubisoft.com', TRUE);

-- Insert Games (with variety including free games)
INSERT INTO games (title, description, genre, category_id, price, discount_percent, publisher_id, release_date, is_featured, is_free, age_rating, file_size) VALUES 
('GTA VI', 'The most anticipated open-world crime game with stunning graphics', 'Action', 1, 69.99, 0, 2, '2025-12-01', TRUE, FALSE, 'M', '150 GB'),
('FIFA 26', 'Most realistic football simulation', 'Sports', 2, 59.99, 10, 1, '2025-09-20', TRUE, FALSE, 'E', '50 GB'),
('Zelda: TOTK', 'Epic adventure in Hyrule', 'Adventure', 5, 59.99, 0, 3, '2025-05-12', FALSE, FALSE, 'E10+', '16 GB'),
('Red Dead 3', 'Western epic with emotional storytelling', 'Action', 1, 64.99, 15, 2, '2025-11-15', TRUE, FALSE, 'M', '120 GB'),
('Madden NFL 26', 'Premium NFL simulation', 'Sports', 2, 54.99, 0, 1, '2025-08-18', FALSE, FALSE, 'E', '45 GB'),
('CS2', 'Competitive tactical shooter', 'Shooter', 6, 0.00, 0, 4, '2024-09-01', FALSE, TRUE, 'M', '25 GB'),
('Dota 2', 'Multiplayer online battle arena', 'Strategy', 4, 0.00, 0, 4, '2013-07-09', FALSE, TRUE, 'T', '30 GB'),
('Fortnite Battle Royale', 'Popular battle royale game', 'Shooter', 6, 0.00, 0, 1, '2017-09-26', TRUE, TRUE, 'T', '40 GB'),
('Elden Ring II', 'Dark fantasy RPG sequel', 'RPG', 3, 69.99, 0, 4, '2025-03-25', TRUE, FALSE, 'M', '60 GB'),
('AC: Shadows', 'Stealth action in feudal Japan', 'Action', 1, 59.99, 10, 5, '2025-11-11', TRUE, FALSE, 'M', '100 GB'),
('The Sims 5', 'Life simulation game', 'Simulation', 7, 49.99, 0, 1, '2025-02-14', FALSE, FALSE, 'T', '35 GB'),
('NBA 2K26', 'Ultimate basketball simulation', 'Sports', 2, 69.99, 0, 1, '2025-09-05', FALSE, FALSE, 'E', '90 GB'),
('Silent Hill', 'Psychological horror', 'Horror', 8, 54.99, 0, 5, '2025-10-31', TRUE, FALSE, 'M', '50 GB'),
('Mario Kart 9', 'Racing fun with Nintendo characters', 'Sports', 2, 49.99, 0, 3, '2025-06-15', FALSE, FALSE, 'E', '8 GB'),
('Civilization VII', 'Turn-based strategy', 'Strategy', 4, 59.99, 10, 1, '2025-02-11', FALSE, FALSE, 'E10+', '20 GB');

-- Sample Reviews
INSERT INTO reviews (user_id, game_id, rating, review_text) VALUES 
(1, 1, 5, 'Absolutely stunning! Best open-world ever.'),
(2, 1, 5, 'Graphics are mind-blowing!'),
(1, 2, 4, 'Great gameplay but career mode needs work.'),
(3, 3, 5, 'Zelda never disappoints!'),
(4, 4, 5, 'Emotional masterpiece!'),
(1, 6, 5, 'Best FPS ever made!'),
(2, 7, 4, 'Complex but rewarding MOBA.');

-- Sample Purchases
INSERT INTO purchases (user_id, game_id, price_paid, payment_method, transaction_id) VALUES
(1, 1, 69.99, 'upi', 'TXN001'),
(1, 2, 53.99, 'card', 'TXN002'),
(2, 3, 59.99, 'upi', 'TXN003'),
(3, 4, 55.24, 'netbanking', 'TXN004');

SELECT 'Advanced database setup complete with Views, Procedures, Functions, and Triggers!' as Status;


-- adding another view
CREATE OR REPLACE VIEW view_game_analytics AS
SELECT 
    g.game_id,
    g.title,
    g.genre,
    g.price,
    g.discount_percent,
    g.publisher_id,
    g.total_sales,
    ROUND(g.price * g.total_sales * (1 - g.discount_percent / 100), 2) as total_revenue,
    ROUND(g.price * (1 - g.discount_percent / 100), 2) as average_sale_price,
    g.average_rating,
    (SELECT COUNT(*) FROM reviews WHERE game_id = g.game_id) as review_count,
    (SELECT COUNT(*) FROM wishlist WHERE game_id = g.game_id) as wishlist_count,
    CASE 
        WHEN (SELECT COUNT(*) FROM wishlist WHERE game_id = g.game_id) > 0 
        THEN (SELECT COUNT(DISTINCT user_id) FROM purchases WHERE game_id = g.game_id) / 
             (SELECT COUNT(*) FROM wishlist WHERE game_id = g.game_id)
        ELSE 0
    END as conversion_rate
FROM games g;
