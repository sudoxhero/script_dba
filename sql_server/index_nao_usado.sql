SELECT
   OBJECT_NAME(we.object_id) AS table_name,
   COALESCE(we.name, SPACE(0)) AS index_name,
   ps.partition_number,
   ps.row_count,
   CAST((ps.reserved_page_count * 8) / 1024. AS DECIMAL(12, 2)) AS size_in_mb,
   COALESCE(ius.user_seeks, 0) AS user_seeks,
   COALESCE(ius.user_scans, 0) AS user_scans,
   COALESCE(ius.user_lookups, 0) AS user_lookups,
   we.type_desc 
FROM
   sys.all_objects t 
   INNER JOIN
      sys.indexes we 
      ON t.object_id = we.object_id 
   INNER JOIN
      sys.dm_db_partition_stats ps 
      ON we.object_id = ps.object_id 
      AND we.index_id = ps.index_id 
   LEFT OUTER JOIN
      sys.dm_db_index_usage_stats ius 
      ON ius.database_id = DB_ID() 
      AND we.object_id = ius.object_id 
      AND we.index_id = ius.index_id 
WHERE
   we.type_desc NOT IN 
   (
      'HEAP',
      'CLUSTERED' 
   )
   AND we.is_unique = 0 
   AND we.is_primary_key = 0 
   AND we.is_unique_constraint = 0 
   AND COALESCE(ius.user_seeks, 0) <= 0 
   AND COALESCE(ius.user_scans, 0) <= 0 
   AND COALESCE(ius.user_lookups, 0) <= 0 
ORDER BY
   OBJECT_NAME(we.object_id),
       we.name;
