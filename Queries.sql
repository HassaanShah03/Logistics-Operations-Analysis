CREATE DATABASE logistics_db;
use logistics_db;



-- UNDERSTAINDING DATA -- 
SELECT * FROM customers
limit 100;

SELECT * FROM delivery_events
limit 100;

select * from driver_monthly_metrics
limit 100;

SELECT * FROM drivers
limit 100;

SELECT * FROM facilities
limit 100;

SELECT * FROM fuel_purchases
limit 100;

SELECT * FROM loads
limit 100;

SELECT * FROM maintenance_records
limit 100;

SELECT * FROM routes
limit 100;

SELECT * FROM trailers
limit 100;

SELECT * FROM trips
limit 100;

SELECT * FROM truck_utilization_metrics
limit 100;

SELECT * FROM trucks
limit 100;

-- Delayed Pickup/Deliver --
select on_time_flag,count(*) as total, round(count(*) * 100 / sum(count(*)) over (), 2) as percent from delivery_events 
where event_type = "Pickup"
group by on_time_flag;

select on_time_flag,count(*) as total, round(count(*) * 100 / sum(count(*)) over (), 2) as percent from delivery_events 
where event_type = "Delivery"
group by on_time_flag;
-- Almost 1/3rd of the pickup are failing to be on time meanwhile 45% of the deleveries are late --




-- Facility Efficiency --
select a.facility_name,count(*) as total, round(count(*) * 100 / sum(count(*)) over (), 2) as percent
 from (select f.facility_id, f.facility_name,f.facility_type, d.event_type,d.on_time_flag from facilities f inner join delivery_events d
on f.facility_id = d.facility_id) a
where a.event_type = 'Pickup'
and a.on_time_flag = 'False'
group by a.facility_name
order by count(*) desc;

select a.facility_name,count(*) as total, round(count(*) * 100 / sum(count(*)) over (), 2) as percent
 from (select f.facility_id, f.facility_name,f.facility_type, d.event_type,d.on_time_flag from facilities f inner join delivery_events d
on f.facility_id = d.facility_id) a
where a.event_type = 'Delivery'
and a.on_time_flag = 'False'
group by a.facility_name
order by count(*) desc;

-- Nashville Distribution Center, Detroit Hub, Atlanta Warehouse are the most inefficient facilities out of all whereas  -- 
-- Houston Distribution Center remains the most efficient                                                                --




-- Driver Efficiency -- 
SELECT DISTINCT driver_name,COUNT(*) OVER (PARTITION BY driver_name) AS total_flags,
COUNT(CASE WHEN on_time_flag = 'False' THEN 1 END) OVER (PARTITION BY driver_name) AS total_false,
ROUND(COUNT(CASE WHEN on_time_flag = 'False' THEN 1 END) OVER (PARTITION BY driver_name) * 100.0 /COUNT(*) OVER (PARTITION BY driver_name),2) AS percent_false
FROM (select a.trip_id,a.driver_id, a.driver_name,de.event_type, de.on_time_flag from 
(select t.trip_id,d.driver_id, concat(d.first_name,' ', d.last_name) driver_name from trips t inner join drivers d
on t.driver_id = d.driver_id) a inner join delivery_events de
on a.trip_id = de.trip_id) f
order by percent_false desc;




-- Trucks Efficiency-- 
SELECT f.truck_id as truck_id,round(f.fuel_cost,2)as fuel_cost,round(m.maintenance_cost,2)as maintenance_cost
,round((f.fuel_cost + m.maintenance_cost),2) AS total_cost,t.trips_completed,
ROUND((f.fuel_cost + m.maintenance_cost) / NULLIF(t.trips_completed, 0),2) AS cost_per_trip
FROM (SELECT truck_id, SUM(total_cost) AS fuel_cost FROM fuel_purchases
GROUP BY truck_id) f
JOIN (SELECT truck_id, SUM(total_cost) AS maintenance_cost FROM maintenance_records
GROUP BY truck_id) m ON f.truck_id = m.truck_id
JOIN (SELECT truck_id, SUM(trips_completed) AS trips_completed FROM truck_utilization_metrics
GROUP BY truck_id) t ON f.truck_id = t.truck_id
ORDER BY cost_per_trip DESC;

-- Using total fuel cost, total maintenance_cost and totalt rips compled we calculated the cost per trip.
-- Trucks with the maximum cost per trip are problem asset--


-- Driver Truck Combo --
SELECT CONCAT(d.first_name, ' ', d.last_name) AS driver_name,tr.truck_id,COUNT(tr.trip_id) AS total_trips,
round(f.fuel_cost,2) as fuel_cost,round(m.maintenance_cost,2)as maintenance_cost,
ROUND((f.fuel_cost + m.maintenance_cost) / NULLIF(COUNT(tr.trip_id), 0),2) AS cost_per_trip
FROM trips tr JOIN drivers d ON tr.driver_id = d.driver_id
inner JOIN (SELECT truck_id, SUM(total_cost) AS fuel_cost FROM fuel_purchases
GROUP BY truck_id) f ON tr.truck_id = f.truck_id
inner JOIN (SELECT truck_id, SUM(total_cost) AS maintenance_cost FROM maintenance_records
GROUP BY truck_id) m ON tr.truck_id = m.truck_id
GROUP BY driver_name, tr.truck_id, f.fuel_cost, m.maintenance_cost
ORDER BY cost_per_trip desc
limit 10;
-- 10 worst combos --

SELECT CONCAT(d.first_name, ' ', d.last_name) AS driver_name,tr.truck_id,COUNT(tr.trip_id) AS total_trips,
round(f.fuel_cost,2) as fuel_cost,round(m.maintenance_cost,2)as maintenance_cost,
ROUND((f.fuel_cost + m.maintenance_cost) / NULLIF(COUNT(tr.trip_id), 0),2) AS cost_per_trip
FROM trips tr JOIN drivers d ON tr.driver_id = d.driver_id
inner JOIN (SELECT truck_id, SUM(total_cost) AS fuel_cost FROM fuel_purchases
GROUP BY truck_id) f ON tr.truck_id = f.truck_id
inner JOIN (SELECT truck_id, SUM(total_cost) AS maintenance_cost FROM maintenance_records
GROUP BY truck_id) m ON tr.truck_id = m.truck_id
GROUP BY driver_name, tr.truck_id, f.fuel_cost, m.maintenance_cost
ORDER BY cost_per_trip desc
limit 10;
-- 10 best combos --
