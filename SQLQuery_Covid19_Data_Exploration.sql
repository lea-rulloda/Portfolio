/*
Data Exploration of COVID-19 Global Figures
Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types
*/

-- Querying Covid_Deaths table
SELECT *
FROM Portfolio..Covid_Deaths
WHERE continent IS NOT NULL
ORDER BY 3,4;

-- Querying relevant information
SELECT location, date, total_cases, new_cases, total_deaths, population
FROM Portfolio..Covid_Deaths
WHERE continent IS NOT NULL
ORDER BY 1, 2;

-- Total Cases x Total Deaths in the Philippines
SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS case_fatality_rate
FROM Portfolio..Covid_Deaths
WHERE location LIKE 'Philippines'
ORDER BY 1, 2;

-- Total Cases x Population in the Philippines
-- Shows what percentage of population was infected with Covid
SELECT location, date, population, total_cases, (total_cases/population)*100 AS cases_percentage
FROM Portfolio..Covid_Deaths
WHERE location LIKE 'Philippines'
ORDER BY 1, 2;

-- Querying infection rate by country sorted from highest to lowest
SELECT location, population, MAX(total_cases) AS highest_total_cases, (MAX(total_cases)/population)*100 AS cases_percentage
FROM Portfolio..Covid_Deaths
GROUP BY location, population
ORDER BY cases_percentage DESC;

-- Querying total death count by country sorted from highest to lowest
SELECT location, MAX(Cast(total_deaths AS int)) AS total_death_count
FROM Portfolio..Covid_Deaths
WHERE continent IS NOT NULL 
GROUP BY location
ORDER BY total_death_count DESC;

-- Querying total death count by continent using CTE
WITH deaths_by_continent
AS
(
SELECT continent, MAX(CAST(total_deaths AS int)) AS total_deaths
FROM Portfolio..Covid_Deaths
WHERE continent IS NOT NULL
GROUP BY continent, location
)
SELECT continent, SUM(total_deaths) AS total_death_count
FROM deaths_by_continent
GROUP BY continent
ORDER BY total_death_count DESC;

-- Global Numbers
SELECT SUM(total_cases) AS total_cases, SUM(country_deaths) AS total_deaths, (SUM(country_deaths)/SUM(total_cases))*100 AS case_fatality_rate,
SUM(max_vax) AS total_people_vaccinated, (SUM(max_vax)/SUM(population))*100 AS vax_rate
FROM 
(
  SELECT dth.location, dth.population,
  MAX(CONVERT(bigint,people_vaccinated)) AS max_vax, SUM(CAST(dth.new_deaths AS float)) AS country_deaths,
  SUM(CAST(dth.new_cases AS float)) AS total_cases
  FROM Portfolio..Covid_Deaths dth 
  JOIN Portfolio..Covid_Vaccinations vax 
	ON dth.location = vax.location AND dth.date = vax.date 
  WHERE dth.continent IS NOT NULL 
  GROUP BY dth.location, dth.population
)
AS totalvax

-- Total Vaccinations x Population
SELECT dth.continent, dth.location, dth.date, dth.population, vax.new_people_vaccinated_smoothed AS new_people_vaccinated,
SUM(CONVERT(bigint,vax.new_people_vaccinated_smoothed)) OVER (PARTITION BY dth.location ORDER BY dth.location, dth.date) AS cumulative_people_vaccinated
FROM Portfolio..Covid_Deaths dth
JOIN Portfolio..Covid_Vaccinations vax
	ON dth.location = vax.location
	AND dth.date = vax.date
WHERE dth.continent IS NOT NULL 
ORDER BY 2,3;

-- Showing percentage of population that has recieved at least one covid vaccine

-- Using Common Table Expression (CTE) to perform calculation on PARTITION BY in previous query
WITH VaxRate (continent, location, date, population, new_people_vaccinated_smoothed, cumulative_people_vaccinated)
AS
(
SELECT dth.continent, dth.location, dth.date, dth.population, vax.new_people_vaccinated_smoothed AS new_people_vaccinated,
SUM(CONVERT(bigint,vax.new_people_vaccinated_smoothed)) OVER (PARTITION BY dth.location ORDER BY dth.location, dth.date) AS cumulative_people_vaccinated
FROM Portfolio..Covid_Deaths dth
JOIN Portfolio..Covid_Vaccinations vax
	ON dth.location = vax.location
	AND dth.date = vax.date
WHERE dth.continent IS NOT NULL 
)
SELECT *, (cumulative_people_vaccinated/population)*100 AS people_vaccinated_percentage
FROM VaxRate;

-- Using a Temp Table to perform calculation on PARTITION BY in previous query
CREATE TABLE #VaccinatedPopulationPercentage
(
continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_people_vaccinated numeric,
cumulative_people_vaccinated numeric
)
INSERT INTO #VaccinatedPopulationPercentage
SELECT dth.continent, dth.location, dth.date, dth.population, vax.new_people_vaccinated_smoothed AS new_people_vaccinated,
SUM(CONVERT(bigint,vax.new_people_vaccinated_smoothed)) OVER (PARTITION BY dth.location ORDER BY dth.location, dth.date) AS cumulative_people_vaccinated
FROM Portfolio..Covid_Deaths dth
JOIN Portfolio..Covid_Vaccinations vax
	ON dth.location = vax.location
	AND dth.date = vax.date
WHERE dth.continent IS NOT NULL 

SELECT *, (cumulative_people_vaccinated/population)*100 AS people_vaccinated_percentage
FROM #VaccinatedPopulationPercentage
DROP TABLE #VaccinatedPopulationPercentage;

-- Creating a view
USE Portfolio
GO
CREATE VIEW VaccinatedPopulationPercentage AS
SELECT dth.continent, dth.location, dth.date, dth.population, vax.new_people_vaccinated_smoothed AS new_people_vaccinated,
SUM(CONVERT(bigint,vax.new_people_vaccinated_smoothed)) OVER (PARTITION BY dth.location ORDER BY dth.location, dth.date) AS cumulative_people_vaccinated
FROM Portfolio..Covid_Deaths dth
JOIN Portfolio..Covid_Vaccinations vax
	ON dth.location = vax.location
	AND dth.date = vax.date
WHERE dth.continent IS NOT NULL

SELECT *, (cumulative_people_vaccinated/population)*100 AS people_vaccinated_percentage
FROM VaccinatedPopulationPercentage;


--Using CTE to show only max people vaccinated
WITH MaxVax
AS
(
  SELECT dth.location, dth.population,
  SUM(CONVERT(bigint,vax.new_people_vaccinated_smoothed)) OVER (PARTITION BY dth.location ORDER BY dth.location, dth.date) AS cumulative_people_vaccinated
  FROM Portfolio..Covid_Deaths dth 
  JOIN Portfolio..Covid_Vaccinations vax 
  ON dth.location = vax.location AND dth.date = vax.date 
  WHERE dth.continent IS NOT NULL 
)
SELECT location, population, MAX(cumulative_people_vaccinated) AS max_cumulative_people_vaccinated, (MAX(cumulative_people_vaccinated)/population)*100 AS people_vaccinated_percentage
FROM MaxVax
GROUP BY location, population
ORDER BY people_vaccinated_percentage DESC;

/*
Vaccination rate is more than 100% in some countries,
the most vaccinated place in the world: Gibraltar for example,
also administered vaccinations for guest workers from Spain which is not part of their population.
*/

-- Case Fatality Rate x Vaccination Rate Using CTE
WITH CFRVaxRate
AS
(
SELECT dth.continent, dth.location, dth.date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS case_fatality_rate, dth.population, vax.new_people_vaccinated_smoothed AS new_people_vaccinated,
SUM(CONVERT(bigint,vax.new_people_vaccinated_smoothed)) OVER (PARTITION BY dth.location ORDER BY dth.location, dth.date) AS cumulative_people_vaccinated
FROM Portfolio..Covid_Deaths dth
JOIN Portfolio..Covid_Vaccinations vax
	ON dth.location = vax.location
	AND dth.date = vax.date
WHERE dth.continent IS NOT NULL 
)
SELECT *, (cumulative_people_vaccinated/population)*100 AS people_vaccinated_percentage
FROM CFRVaxRate
ORDER BY 1,2,3
