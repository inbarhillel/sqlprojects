-- Data Analysis Project - World Layoffs

/*
STAGE 1: CLEANING
*/

-- Create a staging table
CREATE TABLE `layoffs_staging` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


INSERT layoffs_staging
SELECT *
FROM layoffs;

-- Step 1: Removing Duplicates
/* 
The idea: look for identical rows with same values (or nulls) in each column and attaching a counter to them via 'row_num' column
if identical, row_num > 1, thus we can filter and remove duplicate columns 
*/ 

-- Testing method with a cte-created duplicate
WITH duplicate_cte AS 
(
SELECT *,
ROW_NUMBER() OVER(PARTITION  BY company, location, industry, total_laid_off, 
								percentage_laid_off, `date`, stage, country, funds_raised_millions) 
AS row_num
FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

-- Creating new table for insertion of 'row_num' column
CREATE TABLE `layoffs_staging2` ( 
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO layoffs_staging2
SELECT *, 
ROW_NUMBER() OVER(PARTITION  BY company, location, industry, total_laid_off, 
								percentage_laid_off, `date`, stage, country, funds_raised_millions) 
AS row_num
FROM layoffs_staging;

-- Deleting duplicates
DELETE
FROM layoffs_staging2
WHERE row_num > 1;

-- Deleted!
SELECT *
FROM layoffs_staging2
WHERE row_num > 1;


/* 
Step 2: Deleting nulls/blanks
Remove unusable info
Unusable info: rows where 'total_laid_off' and 'percentage_laid_off' are null/blank
*/

SELECT * 
FROM layoffs_staging2
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;

DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL AND percentage_laid_off IS NULL;

/*
Step 3: Standardizing the data
*/

-- Trim columns:

UPDATE layoffs_staging2
SET
  company = TRIM(company),
  location = TRIM(location),
  industry = TRIM(industry),
  stage = TRIM(stage),
  country = TRIM(country);
  
  
  
-- Next: Convert date format from text to proper date

-- Checking the method via cte
WITH date_parsed_cte AS (
  SELECT *,
  STR_TO_DATE(`date`, '%m/%d/%Y') AS parsed_date
  FROM layoffs_staging2
)
SELECT *,
DATE_FORMAT(parsed_date, '%d/%m/%Y') AS converted_date
FROM date_parsed_cte;

-- Implementing on table

SELECT `date`, STR_TO_DATE(`date`, '%m/%d/%Y') AS converted
FROM layoffs_staging2
LIMIT 10;

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y'); -- Done.

SELECT *
FROM layoffs_staging2;

/*
Step 4: Trimming
*/

SELECT DISTINCT country
FROM layoffs_staging2;
-- We can see inconsistencies with US entries

SELECT *
FROM layoffs_staging2
WHERE country LIKE 'United States%';

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country);

SELECT DISTINCT industry
FROM layoffs_staging2;
-- Crypto Currency has 3 instances, one misspelled, one just 'Crypto'

SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry IN ('CryptoCurrency', 'Crypto Currency');

SELECT DISTINCT location
FROM layoffs_staging2;

SELECT DISTINCT stage
FROM layoffs_staging2;

-- Cleaning Done!

/*
STAGE 2: EXPLORATORY ANALYSIS
*/

-- I. Countries ranked by layoff amount/Average layoff percentage

SELECT country, SUM(total_laid_off) AS total_layoffs, 
	   CONCAT(AVG(ROUND(percentage_laid_off * 100, 2)), '%') AS layoff_percentage
FROM layoffs_staging2
GROUP BY country;
/*
Most total layoffs: United States
Largest layoff percentage: Vietnam
*/

-- II. Most layoffs by date

SELECT `date`, SUM(total_laid_off) AS total_layoffs
FROM layoffs_staging2
GROUP BY `date`;
/*
Worst day: 04/01/2023
Best day: 18/03/2020 (According to available data)
*/

SELECT 
  DATE_FORMAT(`date`, '%Y/%m') AS date_month,
  SUM(total_laid_off) AS layoffs
FROM layoffs_staging2
GROUP BY date_month
ORDER BY date_month;

/*
Worst month: January 2023
Best month: October 2021
*/

SELECT 
  DATE_FORMAT(`date`, '%Y') AS date_year,
  SUM(total_laid_off) AS layoffs
FROM layoffs_staging2
GROUP BY date_year
ORDER BY date_year;

/*
Best year: 2021
Worst year: 2022
*/

-- Yearly layoffs by country
SELECT 
  country,
  DATE_FORMAT(`date`, '%Y') AS date_year,
  SUM(total_laid_off) AS total_layoffs
FROM layoffs_staging2
GROUP BY country, date_year
ORDER BY country, date_year;
/*

*/
-- Total layoffs by industry
SELECT 
  industry,
  SUM(total_laid_off) AS total_layoffs
FROM layoffs_staging2
GROUP BY industry
ORDER BY industry;

/*
Hardest hit industry: Consumer
Least hardest hit industry: Manufacturing
*/


WITH yearly_layoffs AS (
  SELECT country,
  DATE_FORMAT(`date`, '%Y') AS date_year,
  SUM(total_laid_off) AS yearly_total
  FROM layoffs_staging2
  GROUP BY country, date_year
),
ranked_years AS (
SELECT *, RANK() OVER (PARTITION BY country ORDER BY yearly_total DESC) AS rnk
FROM yearly_layoffs
)
SELECT country,
MAX(yearly_total) AS max_yearly_layoffs,
MAX(CASE WHEN rnk = 1 THEN date_year END) AS worst_year
FROM ranked_years
GROUP BY country
ORDER BY country;

/*
Worst: United States, 2022 with 106,520 layoffs
Best: Poland, 2022 with 25 layoffs
*/