set linesize 30000
col "Tablespace Name" for a50
col "Allocated (MB)" for 999999
col "Free (MB)" for 999999
col "Used (MB)" for 999999
col "% Free" for 999
col "% Used" for 999
col "Max. Bytes (MB)" for 99999999999

select  a.tablespace_name as "Tablespace Name",
       round(a.bytes_alloc / 1024 / 1024) "Allocated (MB)",
       round(nvl(b.bytes_free, 0) / 1024 / 1024) "Free (MB)",
       round((a.bytes_alloc - nvl(b.bytes_free, 0)) / 1024 / 1024) "Used (MB)",
       round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100) "% Free",
       100 - round((nvl(b.bytes_free, 0) / a.bytes_alloc) * 100) "% Used",
       round(maxbytes/1024 / 1024) "Max. Bytes (MB)"
from  ( select  f.tablespace_name,
               sum(f.bytes) bytes_alloc,
               sum(decode(f.autoextensible, 'YES',f.maxbytes,'NO', f.bytes)) maxbytes
        from dba_data_files f
        group by tablespace_name) a,
      ( select  f.tablespace_name,
               sum(f.bytes)  bytes_free
        from dba_free_space f
        group by tablespace_name) b
where a.tablespace_name = b.tablespace_name (+)
union all
select 
       h.tablespace_name as tablespace_name,
       round(sum(h.bytes_free + h.bytes_used) / 1048576) megs_alloc,
       round(sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / 1048576) megs_free,
       round(sum(nvl(p.bytes_used, 0))/ 1048576) megs_used,
       round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100) Pct_Free,
       100 - round((sum((h.bytes_free + h.bytes_used) - nvl(p.bytes_used, 0)) / sum(h.bytes_used + h.bytes_free)) * 100) pct_used,
       round(sum(f.maxbytes) / 1048576) max
from   (select distinct * from sys.gv_$TEMP_SPACE_HEADER) h, (select distinct * from sys.gv_$Temp_extent_pool) p, dba_temp_files f
where  p.file_id(+) = h.file_id
and    p.tablespace_name(+) = h.tablespace_name
and    f.file_id = h.file_id
and    f.tablespace_name = h.tablespace_name
group by h.tablespace_name
ORDER BY 6 DESC;
