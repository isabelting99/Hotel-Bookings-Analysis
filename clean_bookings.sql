-- CREATING / CLEANING MASTER BOOKINGS TABLE
-- Create 'bookings' table from csv file
CREATE TABLE bookings (
	Booking_ID VARCHAR(50) PRIMARY KEY, 
	no_of_adults INT, 
	no_of_children INT, 
	no_of_weekend_nights INT, 
	no_of_week_nights INT, 
	type_of_meal_plan VARCHAR(50),
	required_car_parking_space INT, 
	room_type_reserved VARCHAR(50), 
	btw_time INT, -- # of days btw date of booking & arrival date 
	arrival_year INT, 
	arrival_month INT, 
	arrival_date INT, 
	repeated_guest INT, 
	no_of_previous_cancellations INT, 
	no_of_previous_bookings_not_cancelled INT, 
	avg_price_per_room FLOAT, 
	no_of_special_requests INT,
	booking_status VARCHAR(30)
);

-- Rename long column names for clarity
ALTER TABLE bookings
RENAME COLUMN no_of_adults TO adults; 

ALTER TABLE bookings
RENAME COLUMN no_of_children TO kids; 	

ALTER TABLE bookings 
RENAME COLUMN no_of_weekend_nights TO weekend_nights;	

ALTER TABLE bookings 
RENAME COLUMN no_of_week_nights TO week_nights;

ALTER TABLE bookings 
RENAME COLUMN type_of_meal_plan TO meal_plan;

ALTER TABLE bookings 
RENAME COLUMN required_car_parking_space TO parking_space;

ALTER TABLE bookings 
RENAME COLUMN room_type_reserved TO room_type;

ALTER TABLE bookings 
RENAME COLUMN repeated_guest TO is_repeated_guest;

ALTER TABLE bookings 
RENAME COLUMN no_of_previous_cancellations TO prev_cancel;

ALTER TABLE bookings 
RENAME COLUMN no_of_previous_bookings_not_cancelled TO prev_kept;

ALTER TABLE bookings 
RENAME COLUMN avg_price_per_room TO avg_price;

ALTER TABLE bookings 
RENAME COLUMN no_of_special_requests TO special_req;

-- Get # of bookings ('kept'/'cancelled') for each meal plan
SELECT meal_plan, COUNT(*)
FROM bookings 
GROUP BY meal_plan

-- Update values for 'meal_plan' for clarity
UPDATE bookings
SET meal_plan = 'breakfast' 
WHERE meal_plan = 'Meal Plan 1';

UPDATE bookings
SET meal_plan = 'half set' -- Breakfast + 1 other meal
WHERE meal_plan = 'Meal Plan 2';

UPDATE bookings
SET meal_plan = 'full set' -- Breakfast, lunch, dinner
WHERE meal_plan = 'Meal Plan 3';

UPDATE bookings 
SET meal_plan = 'none'
WHERE meal_plan = 'Not Selected';

-- Change 'avg_price' from euros to dollars
UPDATE bookings 
SET avg_price = ROUND(
				CAST(avg_price AS NUMERIC)*1.0703,2
					 ); 
-- Used conversion rate from 2023-01-01 (when dataset was ~ uploaded)

-- Rename 'avg_price' to 'room_price_usd' 
ALTER TABLE bookings
RENAME COLUMN avg_price TO room_price_usd;

-- Get distinct room types
SELECT DISTINCT room_type 
FROM bookings
ORDER BY 1; -- 7 room types

-- Extract # only from 'room_type' value for simplicity
UPDATE bookings 
SET room_type = SUBSTRING(room_type,11,1); 
-- Note: Unable to permanently change VARCHAR to INT data type

-- Rename 'arrival_date' column to 'arrival_day' for clarity 
-- when creating new column later on for full date
ALTER TABLE bookings 
RENAME COLUMN arrival_date TO arrival_day;

-- Delete 37 rows with invalid '2018-02-29' date
SELECT * 
FROM bookings 
WHERE arrival_month = 2 AND arrival_day = 29;

DELETE FROM bookings 
WHERE arrival_month = 2 AND arrival_day = 29;

-- Get new date column formatted YYYY-MM-DD: 'arrival_date'
ALTER TABLE bookings
ADD COLUMN arrival_date DATE

UPDATE bookings 
SET arrival_date = MAKE_DATE(arrival_year, arrival_month, arrival_day)

-- Add 'season' column based on USA seasons (same as European seasons)
-- Note: Dataset does not reveal location of hotels; USA location assumed as default
ALTER TABLE bookings
ADD COLUMN season_usa VARCHAR(30);

-- Set values for 'season_usa' column
UPDATE bookings 
SET season_usa = 'winter'
WHERE arrival_month = 12 OR arrival_month = 1 OR arrival_month = 2;

UPDATE bookings 
SET season_usa = 'spring'
WHERE arrival_month BETWEEN 3 AND 5;

UPDATE bookings 
SET season_usa = 'summer'
WHERE arrival_month BETWEEN 6 AND 8;

UPDATE bookings 
SET season_usa = 'fall'
WHERE arrival_month BETWEEN 9 AND 11;



-- GET CANCELLATION RATES BY SEASON
-- Get absolute # of cancellations per season;
-- store values in 'cancellations' table
SELECT season_usa, COUNT(*) AS cancelled
INTO cancellations
FROM bookings
WHERE booking_status = 'cancelled'
GROUP BY season_usa
ORDER BY COUNT(*) DESC;

-- Get total bookings per season; store values in 'total_bookings' table
SELECT season_usa, COUNT(*) AS booked
INTO total_bookings
FROM bookings
GROUP BY season_usa
ORDER BY COUNT(*) DESC;

-- Full outer join for 'cancellations' & 'total_bookings_seasons' on 'season_usa'
SELECT cancellations.season_usa, cancelled, booked
INTO cancel_rate
FROM cancellations
FULL OUTER JOIN total_bookings
ON cancellations.season_usa = total_bookings.season_usa;

-- Add 'cancellation_rate' column 
ALTER TABLE cancel_rate
ADD cancellation_rate NUMERIC;

-- Fill in values for 'cancellation_rate' = ('cancelled'/'booked')*100
UPDATE cancel_rate
SET cancellation_rate = 
	ROUND(
		(
			CAST(cancelled AS NUMERIC) / 
			CAST(booked AS NUMERIC)
		),2
	); 

-- Get final cancellation rates by season DESC order
SELECT season_usa, cancellation_rate
FROM cancel_rate
ORDER BY cancellation_rate DESC 
-- FINDINGS: highest cancellation rate in summer! 
-- Summer (41%), spring (34%), fall (33%), winter (15%)



-- ANALYZING BOOKINGS BOOKED FAR OUT FROM / CLOSE TO ARRIVAL DATE
-- Get 'kept' booking with the furthest out booking date
SELECT MAX(btw_time) 
FROM bookings
WHERE booking_status = 'kept'; -- 386 days

-- Get 'cancelled' booking with the furthest out booking date 
SELECT MAX(btw_time) 
FROM bookings
WHERE booking_status = 'cancelled'; -- 443 days 

-- Get avg 'btw_time' for bookings by 'booking_status'
SELECT booking_status, 
	   ROUND(AVG(btw_time),0) AS btw_time
FROM bookings 
GROUP BY booking_status; 
-- Much higher 'btw_time' for 'cancelled' bookings (139) vs. 'kept' bookings (59)
-- Makes sense! More likely to cancel booking if you booked very far out. 



-- ANALYZING MEAL PLANS FOR KEPT BOOKINGS
-- Get number of 'kept' bookings for guests who ordered some meal plan
SELECT meal_plan, COUNT(*) AS kept_bookings_with_meals
INTO meals
FROM bookings
WHERE booking_status = 'kept'
GROUP BY meal_plan
ORDER BY COUNT(*) DESC;

-- Add 'percent_meal_type' column to 'meals'
ALTER TABLE meals 
ADD percent_meal_type NUMERIC;

/* Get 'percent_meal_type' 
   by dividing 'kept_bookings_with_meals' by total 'kept' bookings */
UPDATE meals
SET percent_meal_type = 
		ROUND((CAST(kept_bookings_with_meals AS NUMERIC) / 
				   (SELECT COUNT(*) FROM bookings WHERE booking_status = 'kept')
			  ),2
			 )

SELECT * 
FROM meals 
ORDER BY percent_meal_type DESC



-- EXPLORE IF PREV CANCELLATIONS INDICIATE CANCELLATION AGAIN
SELECT booking_status, 
	   COUNT(*) AS prev_cancel
FROM bookings
WHERE prev_cancel > 0 
GROUP BY booking_status
-- 15 guests who prev cancelled cancelled again; 
-- 322 guests who prev cancelled kept booking
-- Just bc you prev cancelled does not mean you are inclined to cancel again!



-- ANALYSIS ON ROOM PRICES BY BOOKING STATUS / SEASON
-- Get avg 'room_price_usd' for 'cancelled' vs. 'kept bookings'
SELECT booking_status, 
	   ROUND(CAST(AVG(room_price_usd) AS NUMERIC),2) AS room_price_usd
FROM bookings 
GROUP BY booking_status;
-- On average, 'cancelled' bookings had higher prices ($118.38) vs. 'kept' bookings ($106.97)

-- Get avg 'room_price_usd' for 'cancelled' vs. 'kept bookings' across seasons
SELECT booking_status, 
	   season_usa, 
	   ROUND(
		   CAST(AVG(room_price_usd) AS NUMERIC),2
	   		) AS room_price_usd
FROM bookings 
GROUP BY season_usa, booking_status
ORDER BY season_usa, booking_status;

-- Create 2 tables with 'cancelled' vs. 'kept' booking prices by seasons
SELECT season_usa, 
	   ROUND(CAST(AVG(room_price_usd) AS NUMERIC),2) AS room_price_cancelled
INTO cancelled_prices_by_season
FROM bookings 
WHERE booking_status = 'cancelled'
GROUP BY season_usa

SELECT season_usa, 
	   ROUND(CAST(AVG(room_price_usd) AS NUMERIC),2) AS room_price_kept
INTO kept_prices_by_season
FROM bookings 
WHERE booking_status = 'kept'
GROUP BY season_usa

-- Create joined table with 'kept' & 'cancelled' room prices by season
SELECT cancelled_prices_by_season.season_usa, room_price_cancelled, room_price_kept
INTO all_prices_by_season
FROM cancelled_prices_by_season
FULL OUTER JOIN kept_prices_by_season
ON cancelled_prices_by_season.season_usa = kept_prices_by_season.season_usa

-- Add column 'diff_room_prices' to 'all_prices_by_season'
ALTER TABLE all_prices_by_season
ADD diff_room_prices NUMERIC

UPDATE all_prices_by_season
SET diff_room_prices = room_price_cancelled - room_price_kept

SELECT * FROM all_prices_by_season
ORDER BY room_price_cancelled DESC
-- 'Kept' bookings always have lower prices than 'cancelled' bookings across seasons
-- Difference in 'cancelled' vs. 'kept' bookings prices most prominent in spring
-- Least prominent in winter

