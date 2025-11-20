prompt ###################################
prompt Verificando diretorios existentes
prompt ###################################

set linesize 30000
col owner for a10
col directory_path for a50
col directory_name for a30

select * from all_directories;
