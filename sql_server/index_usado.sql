-- Visualizar todos os indexes usado pelo menos 1 vez no banco de dados
SELECT
   DB_NAME() AS [database_name],
   DB_ID() AS database_id,
   OBJECT_SCHEMA_NAME(i.[object_id]) AS [schema_name],
   OBJECT_NAME(i.[object_id]) AS [object_name],
   iu.[object_id],
   i.[name],
   --i.index_id,
   i.[type_desc],
   i.is_primary_key,
   i.is_unique,
   i.is_unique_constraint,
   iu.user_seeks,
   iu.user_scans,
   iu.user_lookups,
   iu.user_updates,
   iu.user_seeks + iu.user_scans + iu.user_lookups AS total_uses,
   CASE WHEN (iu.user_seeks + iu.user_scans + iu.user_lookups) > 0
        THEN iu.user_updates/( iu.user_seeks + iu.user_scans + iu.user_lookups )
        ELSE iu.user_updates END AS update_to_use_ratio,
       iu.last_user_seek at time zone 'UTC' at time zone 'E. South America Standard Time' as last_user_seek,
       iu.last_user_scan at time zone 'UTC' at time zone 'E. South America Standard Time' as last_user_scan,
       iu.last_user_lookup at time zone 'UTC' at time zone 'E. South America Standard Time' as last_user_lookup,
       iu.last_user_update at time zone 'UTC' at time zone 'E. South America Standard Time' as last_user_update
FROM sys.dm_db_index_usage_stats iu
RIGHT JOIN sys.indexes i ON iu.index_id = i.index_id AND iu.[object_id] = i.[object_id]
WHERE
   OBJECTPROPERTY(iu.[object_id], 'IsUserTable') = 1 AND is_primary_key = 0
   AND iu.database_id = DB_ID()
ORDER BY
   CASE WHEN (iu.user_seeks + iu.user_scans + iu.user_lookups) > 0
        THEN iu.user_updates/( iu.user_seeks + iu.user_scans + iu.user_lookups )
        ELSE iu.user_updates END DESC

-- Visualizar todos os indexes em uma tabela
SELECT
   DB_NAME() AS [database_name],
   DB_ID() AS database_id,
   OBJECT_SCHEMA_NAME(i.[object_id]) AS [schema_name],
   OBJECT_NAME(i.[object_id]) AS [object_name],
   iu.[object_id],
   i.[name],
   i.index_id,
   i.[type_desc],
   i.is_primary_key,
   i.is_unique,
   i.is_unique_constraint,
   iu.user_seeks,
   iu.user_scans,
   iu.user_lookups,
   iu.user_updates,
   iu.user_seeks + iu.user_scans + iu.user_lookups AS total_uses,
   CASE WHEN (iu.user_seeks + iu.user_scans + iu.user_lookups) > 0
        THEN iu.user_updates/( iu.user_seeks + iu.user_scans + iu.user_lookups )
        ELSE iu.user_updates END AS update_to_use_ratio,
       iu.last_user_seek at time zone 'UTC' at time zone 'E. South America Standard Time' as last_user_seek,
       iu.last_user_scan at time zone 'UTC' at time zone 'E. South America Standard Time' as last_user_scan,
       iu.last_user_lookup at time zone 'UTC' at time zone 'E. South America Standard Time' as last_user_lookup,
       iu.last_user_update at time zone 'UTC' at time zone 'E. South America Standard Time' as last_user_update
FROM sys.dm_db_index_usage_stats iu
RIGHT JOIN sys.indexes i ON iu.index_id = i.index_id AND iu.[object_id] = i.[object_id]
WHERE 
  OBJECT_NAME(i.[object_id]) = <tbl_name>

