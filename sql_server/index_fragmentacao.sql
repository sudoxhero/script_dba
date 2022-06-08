SELECT
   DB_NAME(database_id) AS [Database Name],
   SCHEMA_NAME(tbl.schema_id) AS [Schema Name],
   OBJECT_NAME(ps.OBJECT_ID) AS [Object Name],
   i.name AS [Index Name],
   ps.index_id,
   index_type_desc,
   avg_fragmentation_in_percent,
   fragment_count,
   page_count
FROM
   sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL , 'DETAILED') AS ps 
   INNER JOIN
      sys.indexes AS i WITH (NOLOCK) 
      ON ps.[object_id] = i.[object_id] 
      AND ps.index_id = i.index_id 
   INNER JOIN 
      sys.tables as tbl WITH (NOLOCK) 
      ON ps.object_id = tbl.object_id
WHERE
   ps.index_id != 0
   AND ps.alloc_unit_type_desc IN ( N'IN_ROW_DATA', N'ROW_OVERFLOW_DATA')
   AND database_id = DB_ID() 
   AND page_count > 500 
ORDER BY
   avg_fragmentation_in_percent DESC 
OPTION (RECOMPILE);
