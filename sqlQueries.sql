SELECT *, MIN(user_record_time) 
AS record_time FROM user_records 
LEFT JOIN user ON user.user_id = user_records.user_user_id 
WHERE user_record_time > 0.0 AND maps_map_id = %d 
GROUP BY user_user_id ORDER BY MIN(user_record_time) LIMIT 100


SELECT 
	a.map_zone_id, a.map_zone_checkpoint_order_id,
	a.map_id, b.map_enabled, c.user_stage_records_stage_id,
	IFNULL(MIN(c.user_stage_records_time), 0.0) as stage_record 
FROM map_zones as a
LEFT JOIN maps AS b ON b.map_id = a.map_id
LEFT JOIN user_stage_records AS c on a.map_zone_id = c.user_stage_records_stage_id
WHERE b.map_name = 'surf_classics'
AND a.map_zone_type = 2
AND c.user_stage_record_is_wr = 1
GROUP BY a.map_zone_id
ORDER BY a.map_zone_checkpoint_order_id


SELECT 
	a.map_zone_id, 
	a.map_zone_checkpoint_order_id, 
	a.map_id, 
	a.map_zone_type,
	IFNULL(MIN(c.user_stage_records_time), 0.0) AS stage_record, 
	d.user_name, 
	d.user_steam_id,
	d.user_id,
	COALESCE(d.user_id, %d) as fixed_user_id,
	IF (COALESCE(MIN(c.user_stage_records_time), 0.0) = 0.0, 0, 1) as hasFinished
FROM map_zones as a 
	LEFT JOIN maps AS b ON b.map_id = a.map_id 
	LEFT JOIN user_stage_records AS c on c.user_stage_records_stage_id = a.map_zone_id AND c.user_user_id = %d
	LEFT JOIN user AS d on c.user_user_id = d.user_id 
WHERE b.map_id = 307 
	AND (a.map_zone_type = 2 OR a.map_zone_type = 3)
GROUP BY a.map_zone_id
ORDER BY a.map_zone_checkpoint_order_id


SELECT a.map_zone_id, a.map_zone_checkpoint_order_id, a.map_id, a.map_zone_type, 
IFNULL(MIN(c.user_stage_records_time), 0.0) AS stage_record, d.user_name, d.user_steam_id, d.user_id, 
COALESCE(d.user_id, %d) as fixed_user_id, 
IF (COALESCE(MIN(c.user_stage_records_time), 0.0) = 0.0, 0, 1) as hasFinished 
FROM map_zones as a LEFT JOIN maps AS b ON b.map_id = a.map_id 
LEFT JOIN user_stage_records AS c on c.user_stage_records_stage_id = a.map_zone_id AND c.user_user_id = %d 
LEFT JOIN user AS d on c.user_user_id = d.user_id 
WHERE b.map_id = %d AND (a.map_zone_type = 2 OR a.map_zone_type = 3) 
GROUP BY a.map_zone_id ORDER BY a.map_zone_checkpoint_order_id


g_user[client][Id], g_map[Id], g_user[client][Id]

# select records (min times) from userstage where playerid, mapid group by map zone id, checkpoint order id

#SELECT 
	#a.map_zone_id, 
	#a.map_zone_checkpoint_order_id, 
	#a.map_id, 
	#a.map_zone_type, 
	#b.map_enabled, 
	#IFNULL(MIN(c.user_stage_records_time), 0.0) as stage_record, 
#	d.user_name, 
#	d.user_steam_id 
#FROM map_zones as a 
#	LEFT JOIN maps AS b ON b.map_id = a.map_id 
#	LEFT JOIN user_stage_records AS c on a.map_zone_id = c.user_stage_records_stage_id 
#	LEFT JOIN user AS d on c.user_user_id = d.user_id 
#WHERE b.map_id = 44 AND a.map_zone_type = 2 
#GROUP BY a.map_zone_id 
#ORDER BY a.map_zone_checkpoint_order_id

