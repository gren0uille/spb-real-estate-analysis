/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Камалов Тимур
 * Дата: 15-10-2025
*/


set lc_time = 'ru_RU';
-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
time_of_expos AS (SELECT
	CASE
        WHEN days_exposition > 0 AND days_exposition < 31 THEN 'до месяца'
        WHEN days_exposition > 30 AND days_exposition < 91 THEN 'до трех месяцев'
        WHEN days_exposition > 90 AND days_exposition < 181 THEN 'до полугода'
        WHEN days_exposition > 180 THEN 'более полугода'
        ELSE 'non category'
    END AS time_of_exposition,
    CASE
    	WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
    	ELSE 'ЛенОбласть'
    END AS city_category,
    *
FROM real_estate.flats f
    JOIN real_estate.advertisement a ON f.id = a.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    JOIN real_estate.TYPE t ON f.type_id = t.type_id
WHERE 
	f.id IN (SELECT id FROM filtered_id) AND
	first_day_exposition >= '01-01-2015' AND
	first_day_exposition <= '31-12-2018' AND
	t.type = 'город')
SELECT
    city_category,
    time_of_exposition,
    COUNT(*) AS "кол-во объяв.",
    ROUND(COUNT(*)::NUMERIC / (SELECT COUNT(*) FROM time_of_expos) ,2) AS avg_share,
    ROUND(SUM(last_price)::NUMERIC / SUM(total_area)::NUMERIC,2) AS avg_price_per_kvm,
    ROUND(SUM(total_area)::NUMERIC / COUNT(total_area)::NUMERIC,2) AS avg_area,
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY rooms) AS median_rooms,
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY balcony) AS median_balcony
FROM time_of_expos
GROUP BY city_category, time_of_exposition
ORDER BY 
    city_category DESC,
    CASE
        WHEN time_of_exposition = 'более полугода' THEN 4
        WHEN time_of_exposition = 'до полугода' THEN 3
        WHEN time_of_exposition = 'до трех месяцев' THEN 2
        WHEN time_of_exposition = 'до месяца' THEN 1
        ELSE 5
    END,
    "кол-во объяв." DESC

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
p_2 AS(SELECT
    TO_CHAR(first_day_exposition, 'TMMonth') AS month_name,
    COUNT(*) AS opened_count,
    SUM(CASE WHEN days_exposition IS NOT NULL THEN 1 ELSE 0 END) AS closed_count,
    ROUND(SUM(last_price)::NUMERIC / SUM(total_area)::NUMERIC,2) AS avg_price_per_kvm,
    ROUND(SUM(total_area)::NUMERIC / COUNT(total_area)::NUMERIC,2) AS avg_area
FROM real_estate.flats f
JOIN real_estate.advertisement a ON f.id = a.id
JOIN real_estate.TYPE t ON f.type_id = t.type_id
WHERE f.id IN (SELECT id FROM filtered_id) AND
	first_day_exposition >= '01-01-2015' AND
	first_day_exposition <= '31-12-2018' AND t.TYPE = 'город'
GROUP BY TO_CHAR(first_day_exposition, 'TMMonth')
ORDER BY opened_count DESC),
total_open_close AS (
    SELECT 
    SUM(opened_count) AS total_opened, 
    SUM(closed_count) AS total_closed 
    FROM p_2)
SELECT
	month_name,
	ROW_NUMBER() OVER(ORDER BY opened_count DESC) AS opened_rank,
	ROUND(opened_count / (SELECT total_opened FROM total_open_close)::NUMERIC,2) AS share_opened,
	opened_count,
	ROW_NUMBER() OVER(ORDER BY closed_count DESC) AS closed_rank,
	ROUND(opened_count / (SELECT total_closed FROM total_open_close)::NUMERIC,2) AS share_closed,
	closed_count,
	avg_price_per_kvm,
	avg_area
FROM p_2