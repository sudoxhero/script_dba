set linesize 30000
col Tablespace for a20
col "File Type" for a10
col "Tablespace Status" for  a10
col "File Status" for a10
col "Used (MB)" for 999999999999
col "Free (MB)" for 9999999999999
col "Initial Extent (B)" for 999999
col "Next Extent (B)" for 999999
col "Min. Extents" for 999999
col "Max. Extents" for 9999999999999
col "% Increase" for 999999
col "Datafile Name" for a100
col "File ID" for 999999


SELECT t.tablespace_name "Tablespace",
       'Datafile' "File Type",
       t.status "Tablespace Status",
       d.status "File Status",
       ROUND((d.max_bytes - NVL(f.sum_bytes, 0))/1024/1024) "Used (MB)",
       ROUND(NVL(f.sum_bytes, 0)/1024/1024) "Free (MB)",
       t.initial_extent "Initial Extent (B)",
       t.next_extent "Next Extent (B)",
       t.min_extents "Min. Extents",
       t.max_extents "Max. Extents",
       t.pct_increase "% Increase",
       d.file_name "Datafile Name",
       d.file_id "File ID"
 FROM (SELECT tablespace_name, file_id, SUM(bytes) sum_bytes
       FROM   DBA_FREE_SPACE
       GROUP BY tablespace_name, file_id) f,
      (SELECT tablespace_name, file_name, file_id, MAX(bytes) max_bytes, status
       FROM DBA_DATA_FILES
       GROUP BY tablespace_name, file_name, file_id, status) d,
      DBA_TABLESPACES t
WHERE t.tablespace_name = d.tablespace_name
AND   f.tablespace_name(+) = d.tablespace_name
AND   f.file_id(+) = d.file_id
GROUP BY t.tablespace_name, d.file_name, d.file_id, t.initial_extent,
         t.next_extent, t.min_extents, t.max_extents,
         t.pct_increase, t.status, d.max_bytes, f.sum_bytes, d.status
UNION ALL
SELECT h.tablespace_name,
       'Tempfile',
       ts.status,
       t.status,
       ROUND(SUM(NVL(p.bytes_used, 0))/ 1048576),
       ROUND(SUM((h.bytes_free + h.bytes_used) - NVL(p.bytes_used, 0)) / 1048576),
       null, -- initial extent
       null, -- initial extent
       null, -- min extents
       null, -- max extents
       null, -- pct increase
       t.file_name,
       t.file_id
FROM   sys.GV_$TEMP_SPACE_HEADER h, sys.GV_$TEMP_EXTENT_POOL p, sys.DBA_TEMP_FILES t, sys.dba_tablespaces ts
WHERE  p.file_id(+) = h.file_id
AND    p.tablespace_name(+) = h.tablespace_name
AND    h.file_id = t.file_id
AND    h.tablespace_name = t.tablespace_name
and    ts.tablespace_name = h.tablespace_name
GROUP BY h.tablespace_name, t.status, t.file_name, t.file_id, ts.status
ORDER BY 1, 5 DESC;
